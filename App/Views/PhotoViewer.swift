import SwiftUI

/// Shows the last captured photo.
struct PhotoViewer: View {
    let image: UIImage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(Theme.charcoal.opacity(0.8), in: Circle())
                }
                .accessibilityLabel(Text("viewer.close"))
                Spacer()
                if let image {
                    let picture = Image(uiImage: image)
                    ShareLink(item: picture, preview: SharePreview(L10n.text("viewer.photo"), image: picture)) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 38, height: 38)
                            .background(Theme.charcoal.opacity(0.8), in: Circle())
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .preferredColorScheme(.dark)
    }
}
