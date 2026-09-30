import AVFoundation
import SwiftUI

/// Displays frames produced by `FilteredPreviewRenderer`. The layer uses
/// aspect-fill, matching `PreviewGeometry` used for the overlay.
struct CameraPreview: UIViewRepresentable {
    let renderer: FilteredPreviewRenderer

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.displayLayer.videoGravity = .resizeAspectFill
        renderer.attach(view.displayLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }
        var displayLayer: AVSampleBufferDisplayLayer { layer as! AVSampleBufferDisplayLayer }
    }
}
