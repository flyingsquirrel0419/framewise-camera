import SwiftUI

/// One short, quiet instruction (plus an optional reason) in a small dark pill.
struct TipView: View {
    let tipKey: String
    let reasonKey: String?
    let isOptimal: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: isOptimal ? "checkmark" : "sparkle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.amber.opacity(0.9))
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(tipKey))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.86))
                if let reasonKey {
                    Text(LocalizedStringKey(reasonKey))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .multilineTextAlignment(.leading)
            .lineLimit(2)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.35)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.hairline, lineWidth: 0.5))
        }
        .environment(\.colorScheme, .dark)
        .fixedSize(horizontal: false, vertical: true)
        .id(tipKey + (reasonKey ?? ""))
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
        .accessibilityElement(children: .combine)
    }
}

/// Composition score, shown only when enabled in Settings.
struct ScorePill: View {
    let score: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkle")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.amber)
            Text("\(score)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.85))
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.08), in: Capsule())
        .animation(.smooth(duration: 0.4), value: score)
    }
}
