import AVFoundation
import UIKit

/// Owns the capture session. All session work happens on `sessionQueue`; video
/// frames are delivered on `videoQueue` and handed to `onFrame` synchronously.
/// Because late frames are discarded by AVFoundation while `onFrame` runs, the
/// analysis never builds a backlog and pixel buffers are never copied.
final class CameraManager: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()

    /// Called on the video queue with an upright (portrait, mirrored for the front
    /// camera) pixel buffer.
    var onFrame: ((CVPixelBuffer) -> Void)?

    private let sessionQueue = DispatchQueue(label: "camera.session", qos: .userInitiated)
    private let videoQueue = DispatchQueue(label: "camera.video", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var deviceInput: AVCaptureDeviceInput?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var inFlight: [Int64: PhotoCaptureProcessor] = [:]
    private var isConfigured = false

    static var hasAnyCamera: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    static var authorization: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    // MARK: Lifecycle

    func configure(position: AVCaptureDevice.Position = .back) async -> CameraSetupResult {
        guard Self.authorization == .authorized else { return .notAuthorized }
        guard Self.hasAnyCamera else { return .unavailable }
        return await withCheckedContinuation { continuation in
            sessionQueue.async {
                continuation.resume(returning: self.configureSession(position: position))
            }
        }
    }

    func start() {
        sessionQueue.async {
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func switchCamera() async -> CameraSetupResult {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                let next: AVCaptureDevice.Position = self.deviceInput?.device.position == .front ? .back : .front
                continuation.resume(returning: self.configureSession(position: next))
            }
        }
    }

    func select(_ lens: LensOption) {
        sessionQueue.async {
            guard let device = self.deviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                let factor = min(max(lens.zoomFactor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
                device.ramp(toVideoZoomFactor: factor, withRate: 10)
                device.unlockForConfiguration()
            } catch {
                return
            }
        }
    }

    // MARK: Session configuration (sessionQueue only)

    private func configureSession(position: AVCaptureDevice.Position) -> CameraSetupResult {
        guard let device = Self.bestDevice(for: position) ?? Self.bestDevice(for: position == .back ? .front : .back) else {
            return .unavailable
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canSetSessionPreset(.photo) { session.sessionPreset = .photo }

        if let existing = deviceInput {
            session.removeInput(existing)
            deviceInput = nil
        }
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            return .failed
        }
        session.addInput(input)
        deviceInput = input

        if !session.outputs.contains(videoOutput) {
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            guard session.canAddOutput(videoOutput) else { return .failed }
            session.addOutput(videoOutput)
        }
        if !session.outputs.contains(photoOutput) {
            guard session.canAddOutput(photoOutput) else { return .failed }
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .balanced
        }

        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = device.position == .front
            }
        }

        configureFocus(device)
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)

        let lenses = Self.lensOptions(for: device)
        let initial = lenses.first { $0.displayFactor == 1 } ?? lenses.first
        if let initial, (try? device.lockForConfiguration()) != nil {
            device.videoZoomFactor = min(max(initial.zoomFactor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            device.unlockForConfiguration()
        }
        isConfigured = true
        return .success(CameraConfiguration(position: device.position, lenses: lenses, selectedLens: initial,
                                            supportsFlash: photoOutput.supportedFlashModes.contains(.on)))
    }

    private func configureFocus(_ device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
        if device.isSmoothAutoFocusSupported { device.isSmoothAutoFocusEnabled = true }
        device.unlockForConfiguration()
    }

    private static func bestDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = position == .back
            ? [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
            : [.builtInTrueDepthCamera, .builtInWideAngleCamera]
        for type in types {
            if let device = AVCaptureDevice.default(type, for: .video, position: position) { return device }
        }
        return nil
    }

    /// Virtual multi-camera devices report zoom 1.0 for the ultra wide; the wide
    /// lens ("1×") starts at the first switch-over factor.
    private static func lensOptions(for device: AVCaptureDevice) -> [LensOption] {
        let hasUltraWide = device.constituentDevices.contains { $0.deviceType == .builtInUltraWideCamera }
        let base: CGFloat = hasUltraWide ? CGFloat(device.virtualDeviceSwitchOverVideoZoomFactors.first?.doubleValue ?? 2) : 1
        var options: [LensOption] = []
        if hasUltraWide { options.append(LensOption(displayFactor: 0.5, zoomFactor: 1)) }
        options.append(LensOption(displayFactor: 1, zoomFactor: base))
        if device.position == .back, device.maxAvailableVideoZoomFactor >= base * 2 {
            options.append(LensOption(displayFactor: 2, zoomFactor: base * 2))
        }
        return options
    }

    // MARK: Photo capture

    func capturePhoto(flash: FlashMode, preferHEIF: Bool, willCapture: @escaping @Sendable () -> Void,
                      completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        sessionQueue.async {
            guard self.session.isRunning else {
                completion(.failure(CameraError.captureFailed))
                return
            }
            let settings: AVCapturePhotoSettings
            if preferHEIF, self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            }
            if self.photoOutput.supportedFlashModes.contains(flash.avMode) {
                settings.flashMode = flash.avMode
            }
            settings.photoQualityPrioritization = .balanced

            if let connection = self.photoOutput.connection(with: .video) {
                let angle = self.rotationCoordinator?.videoRotationAngleForHorizonLevelCapture ?? 90
                if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = self.deviceInput?.device.position == .front
                }
            }

            let id = settings.uniqueID
            let processor = PhotoCaptureProcessor(willCapture: willCapture) { [weak self] result in
                self?.sessionQueue.async { self?.inFlight[id] = nil }
                completion(result)
            }
            self.inFlight[id] = processor
            self.photoOutput.capturePhoto(with: settings, delegate: processor)
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(buffer)
    }
}
