import AVFoundation

/// Delegate for a single capture; retained by `CameraManager` until it finishes.
final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let willCapture: @Sendable () -> Void
    private let completion: @Sendable (Result<Data, Error>) -> Void
    private var data: Data?
    private var error: Error?

    init(willCapture: @escaping @Sendable () -> Void, completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        self.willCapture = willCapture
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        willCapture()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error { self.error = error; return }
        data = photo.fileDataRepresentation()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error ?? self.error {
            completion(.failure(error))
        } else if let data {
            completion(.success(data))
        } else {
            completion(.failure(CameraError.noData))
        }
    }
}
