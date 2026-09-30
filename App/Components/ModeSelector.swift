import SwiftUI
import CompositionKit

/// Camera-style mode strip. Tap a mode or swipe on the preview.
struct ModeSelector: View {
    let modes: [CompositionMode]
    let selected: CompositionMode
    let onSelect: (CompositionMode) -> Void

    var body: some View {
        HStack(spacing: 22) {
            ForEach(modes, id: \.self) { mode in
                Button {
                    onSelect(mode)
                } label: {
                    Text(LocalizedStringKey(L10n.modeKey(mode)))
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.1)
                        .textCase(.uppercase)
                        .foregroundStyle(mode == selected ? Theme.amber : Theme.textSecondary)
                        .padding(.vertical, 6)
                }
                .accessibilityAddTraits(mode == selected ? .isSelected : [])
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selected)
    }
}

/// 0.5× / 1× / 2× lens buttons.
struct ZoomSelector: View {
    let lenses: [LensOption]
    let selected: LensOption?
    let onSelect: (LensOption) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(lenses) { lens in
                let isSelected = lens == selected
                Button {
                    onSelect(lens)
                } label: {
                    Text(isSelected ? lens.label + "×" : lens.label)
                        .font(.system(size: isSelected ? 12 : 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? Theme.amber : Theme.textPrimary)
                        .frame(width: isSelected ? 36 : 30, height: isSelected ? 36 : 30)
                        .background(Color.black.opacity(isSelected ? 0.55 : 0.35), in: Circle())
                }
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.22), in: Capsule())
        .animation(.smooth(duration: 0.25), value: selected)
    }
}
