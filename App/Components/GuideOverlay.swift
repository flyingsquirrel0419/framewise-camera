import SwiftUI
import CompositionKit

/// Everything drawn over the live preview: grid, level, candidate subjects,
/// the subject box, the target box and the movement arrow. Rects arrive at the
/// analysis rate (~12 fps) and SwiftUI animates between them, so motion stays
/// smooth at display rate. Taps select a subject or focus on an empty spot.
struct GuideOverlay: View {
    let guide: GuideFrame
    let imageSize: CGSize
    let settings: AppSettings
    let motion: MotionManager.Snapshot
    let selectedID: Int?
    /// Normalized tap location and the subject under it, if any.
    let onTap: (CGPoint, Int?) -> Void

    var body: some View {
        GeometryReader { geo in
            let mapper = PreviewGeometry(viewSize: geo.size, imageSize: imageSize)
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { location in
                        onTap(mapper.normalized(location), hitTest(location, mapper: mapper))
                    }
                Group {
                    if settings.showGrid {
                        GridOverlay()
                    }
                    if settings.showLevel, let deviation = motion.levelDeviation {
                        LevelIndicator(deviation: deviation, rotation: motion.quadrant.uiRotationDegrees)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                    if settings.showCandidates {
                        candidateLayer(mapper: mapper)
                    }
                    if settings.showGuide, let result = guide.result {
                        guideLayer(result, mapper: mapper)
                            .transition(.opacity)
                    }
                }
                .allowsHitTesting(false)
            }
            .animation(.easeInOut(duration: 0.35), value: guide.result == nil)
        }
    }

    /// The smallest subject box under the finger (with a little slop).
    private func hitTest(_ location: CGPoint, mapper: PreviewGeometry) -> Int? {
        guide.subjects
            .map { ($0.id, mapper.rect($0.rect).insetBy(dx: -12, dy: -12)) }
            .filter { $0.1.contains(location) }
            .min { $0.1.width * $0.1.height < $1.1.width * $1.1.height }?
            .0
    }

    private func candidateLayer(mapper: PreviewGeometry) -> some View {
        let primary = settings.showGuide ? guide.result?.subjectID : nil
        return ZStack {
            ForEach(guide.subjects.filter { $0.id != primary }) { subject in
                CandidateBox(rect: mapper.rect(subject.rect),
                             labelKey: L10n.subjectLabelKey(subject.kind),
                             tint: Theme.tint(for: subject.kind))
                    .transition(.opacity)
            }
        }
        .animation(Theme.smooth, value: guide.subjects)
    }

    @ViewBuilder
    private func guideLayer(_ r: CompositionResult, mapper: PreviewGeometry) -> some View {
        let subject = mapper.rect(r.subjectRect)
        let target = mapper.rect(r.targetRect)
        let proximity = 1 - min(Double(r.distance) / 0.3, 1)
        let tint = Theme.tint(for: r.subjectKind)
        ZStack {
            if settings.showTarget {
                TargetBoundingBox(rect: target, proximity: r.isOptimal ? 1 : proximity, tint: tint)
                    .opacity(r.isOptimal ? 0 : 1)
                if !r.isOptimal, r.direction != .closer, r.direction != .farther {
                    MovementArrow(from: subject, to: target, tint: tint)
                        .transition(.opacity)
                }
            }
            SubjectBoundingBox(rect: subject, labelKey: L10n.subjectLabelKey(r.subjectKind), isOptimal: r.isOptimal,
                               tint: tint, isPinned: selectedID != nil && r.subjectID == selectedID)
        }
        .animation(Theme.smooth, value: r.subjectRect)
        .animation(Theme.smooth, value: r.targetRect)
        .animation(.easeInOut(duration: 0.4), value: r.isOptimal)
    }
}

/// Brief square shown where the user tapped to focus.
struct FocusMarkerView: View {
    @State private var settled = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .stroke(Theme.amber.opacity(0.85), lineWidth: 1.2)
            .frame(width: 64, height: 64)
            .scaleEffect(settled ? 1 : 1.25)
            .onAppear { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { settled = true } }
            .allowsHitTesting(false)
    }
}
