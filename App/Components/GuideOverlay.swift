import SwiftUI
import CompositionKit

/// Everything drawn over the live preview: grid, level, subject box, target
/// box and the movement arrow. Rects arrive at the analysis rate (~12 fps) and
/// SwiftUI animates between them, so motion stays smooth at display rate.
struct GuideOverlay: View {
    let guide: GuideFrame
    let imageSize: CGSize
    let settings: AppSettings
    let motion: MotionManager.Snapshot

    var body: some View {
        GeometryReader { geo in
            let mapper = PreviewGeometry(viewSize: geo.size, imageSize: imageSize)
            ZStack {
                if settings.showGrid {
                    GridOverlay()
                }
                if settings.showLevel, let deviation = motion.levelDeviation {
                    LevelIndicator(deviation: deviation, rotation: motion.quadrant.uiRotationDegrees)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                if settings.showGuide, let result = guide.result {
                    guideLayer(result, mapper: mapper)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: guide.result == nil)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func guideLayer(_ r: CompositionResult, mapper: PreviewGeometry) -> some View {
        let subject = mapper.rect(r.subjectRect)
        let target = mapper.rect(r.targetRect)
        let proximity = 1 - min(Double(r.distance) / 0.3, 1)
        ZStack {
            if settings.showTarget {
                TargetBoundingBox(rect: target, proximity: r.isOptimal ? 1 : proximity)
                    .opacity(r.isOptimal ? 0 : 1)
                if !r.isOptimal, r.direction != .closer, r.direction != .farther {
                    MovementArrow(from: subject, to: target)
                        .transition(.opacity)
                }
            }
            SubjectBoundingBox(rect: subject, labelKey: L10n.subjectLabelKey(r.subjectKind), isOptimal: r.isOptimal)
        }
        .animation(Theme.smooth, value: r.subjectRect)
        .animation(Theme.smooth, value: r.targetRect)
        .animation(.easeInOut(duration: 0.4), value: r.isOptimal)
    }
}
