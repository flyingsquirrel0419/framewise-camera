import AVFoundation

enum FlashMode: String, CaseIterable, Sendable {
    case auto, on, off

    var avMode: AVCaptureDevice.FlashMode {
        switch self {
        case .auto: return .auto
        case .on: return .on
        case .off: return .off
        }
    }

    var symbol: String {
        switch self {
        case .auto: return "bolt.badge.automatic"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash"
        }
    }

    var next: FlashMode {
        switch self {
        case .auto: return .on
        case .on: return .off
        case .off: return .auto
        }
    }
}

/// A user-facing lens choice (0.5×, 1×, 2×) mapped to a device zoom factor.
struct LensOption: Identifiable, Equatable, Sendable {
    let displayFactor: CGFloat
    let zoomFactor: CGFloat
    var id: CGFloat { displayFactor }

    var label: String {
        displayFactor < 1 ? ".5" : String(format: "%.0f", displayFactor)
    }
}

struct CameraConfiguration: Equatable, Sendable {
    var position: AVCaptureDevice.Position
    var lenses: [LensOption]
    var selectedLens: LensOption?
    var supportsFlash: Bool
}

enum CameraSetupResult: Sendable {
    case success(CameraConfiguration)
    case notAuthorized
    case unavailable
    case failed
}

enum CameraError: Error {
    case captureFailed
    case noData
}
