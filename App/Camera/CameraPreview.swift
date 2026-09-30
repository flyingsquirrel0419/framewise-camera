import AVFoundation
import SwiftUI

/// Hosts an `AVCaptureVideoPreviewLayer` directly as the view's backing layer.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// Changing the camera recreates the preview connection; re-apply rotation.
    let position: AVCaptureDevice.Position

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.setNeedsLayout()
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            // The UI is portrait-locked; keep the preview upright to match analysis frames.
            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90),
               connection.videoRotationAngle != 90 {
                connection.videoRotationAngle = 90
            }
        }
    }
}
