import SwiftUI

/// Bottom bar: last photo, shutter, camera switch.
struct CameraControls: View {
    let thumbnail: UIImage?
    let isOptimal: Bool
    let isCapturing: Bool
    let onShutter: () -> Void
    let onFlip: () -> Void
    let onThumbnail: () -> Void
    @State private var flipTurns = 0.0

    var body: some View {
        HStack {
            Button(action: onThumbnail) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.charcoal)
                    if let thumbnail {
                        Image(uiImage: thumbnail).resizable().scaledToFill()
                    }
                }
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Theme.hairline, lineWidth: 0.5))
            }
            .disabled(thumbnail == nil)
            .accessibilityLabel(Text("a11y.album"))

            Spacer()
            ShutterButton(isOptimal: isOptimal, isCapturing: isCapturing, action: onShutter)
            Spacer()

            Button {
                withAnimation(.smooth(duration: 0.45)) { flipTurns += 180 }
                onFlip()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Theme.textPrimary)
                    .rotation3DEffect(.degrees(flipTurns), axis: (x: 0, y: 1, z: 0))
                    .frame(width: 46, height: 46)
                    .background(Theme.charcoal, in: Circle())
            }
            .accessibilityLabel(Text("a11y.flip"))
        }
        .padding(.horizontal, 30)
    }
}

struct ShutterButton: View {
    let isOptimal: Bool
    let isCapturing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(isOptimal ? Theme.amber.opacity(0.95) : Color.white.opacity(0.92), lineWidth: 3)
                    .frame(width: 74, height: 74)
                Circle()
                    .fill(Color.white)
                    .frame(width: 61, height: 61)
                    .scaleEffect(isCapturing ? 0.88 : 1)
            }
            .animation(.easeInOut(duration: 0.35), value: isOptimal)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isCapturing)
        }
        .buttonStyle(ShutterPressStyle())
        .accessibilityLabel(Text("a11y.shutter"))
    }
}

private struct ShutterPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
