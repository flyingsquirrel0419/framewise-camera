import SwiftUI

/// The detected subject: thin amber outline with a tiny label above it.
struct SubjectBoundingBox: View {
    let rect: CGRect
    let labelKey: String
    let isOptimal: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .stroke(Theme.amber.opacity(isOptimal ? 0.9 : 0.78), lineWidth: isOptimal ? 1.6 : Theme.guideLine)
            .frame(width: max(rect.width, 1), height: max(rect.height, 1))
            .overlay(alignment: .topLeading) {
                BoxLabel(key: labelKey, opacity: 0.75)
                    .offset(y: -17)
            }
            .overlay(alignment: .topTrailing) {
                if isOptimal {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black.opacity(0.85))
                        .frame(width: 17, height: 17)
                        .background(Theme.amber.opacity(0.85), in: Circle())
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

    var body: some View {
        Text(LocalizedStringKey(key))
            .font(.system(size: 10, weight: .medium))
            .tracking(0.4)
            .foregroundStyle(Theme.amber.opacity(opacity))
            .lineLimit(1)
            .fixedSize()
            .shadow(color: .black.opacity(0.5), radius: 2)
    }
}
