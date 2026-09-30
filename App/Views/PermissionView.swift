import SwiftUI

struct PermissionView: View {
    let isDenied: Bool
    let onAllow: () async -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 46, weight: .ultraLight))
                .foregroundStyle(Theme.amber)
                .padding(.bottom, 6)
            Text("permission.camera.title")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(isDenied ? "permission.camera.denied_message" : "permission.camera.message")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Button {
                if isDenied {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } else {
                    Task { await onAllow() }
                }
            } label: {
                Text(isDenied ? "permission.open_settings" : "permission.allow")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.amber, in: Capsule())
            }
            .padding(.horizontal, 32)
            Text("about.on_device")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary.opacity(0.8))
                .padding(.bottom, 20)
        }
    }
}

struct UnavailableView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "video.slash")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(Theme.amber)
                .padding(.bottom, 6)
            Text("unavailable.title")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("unavailable.message")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
