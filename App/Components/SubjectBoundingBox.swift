import SwiftUI

/// The detected subject: thin amber outline with a tiny label above it.
struct SubjectBoundingBox: View {
    let rect: CGRect
    let labelKey: String
    let isOptimal: Bool
    var tint: Color = Theme.amber
    /// Shown when the user locked this subject by tapping it.
    var isPinned = false

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .stroke(tint.opacity(isOptimal ? 0.9 : 0.78), lineWidth: isOptimal || isPinned ? 1.6 : Theme.guideLine)
            .frame(width: max(rect.width, 1), height: max(rect.height, 1))
            .overlay(alignment: .topLeading) {
                HStack(spacing: 3) {
                    if isPinned {
                        Image(systemName: "scope")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(tint.opacity(0.85))
                    }
                    BoxLabel(key: labelKey, opacity: 0.75, tint: tint)
                }
                .offset(y: -17)
            }
            .overlay(alignment: .topTrailing) {
                if isOptimal {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black.opacity(0.85))
                        .frame(width: 17, height: 17)
                        .background(tint.opacity(0.85), in: Circle())
                        .offset(x: 8, y: -8)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .position(x: rect.midX, y: rect.midY)
    }
}

struct BoxLabel: View {
    let key: String
    let opacity: Double
    var tint: Color = Theme.amber

    var body: some View {
        Text(LocalizedStringKey(key))
            .font(.system(size: 10, weight: .medium))
            .tracking(0.4)
            .foregroundStyle(tint.opacity(opacity))
            .lineLimit(1)
            .fixedSize()
            .shadow(color: .black.opacity(0.5), radius: 2)
    }
}

/// A detected subject that isn't the current focus of the guide. Drawn faintly
/// in its kind's color; tap it to make it the subject.
struct CandidateBox: View {
    let rect: CGRect
    let labelKey: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .stroke(tint.opacity(0.42), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
            .frame(width: max(rect.width, 1), height: max(rect.height, 1))
            .overlay(alignment: .topLeading) {
                HStack(spacing: 4) {
                    Circle().fill(tint.opacity(0.8)).frame(width: 5, height: 5)
                    BoxLabel(key: labelKey, opacity: 0.55, tint: tint)
                }
                .offset(y: -16)
            }
            .position(x: rect.midX, y: rect.midY)
    }
}
