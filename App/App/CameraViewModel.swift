import AVFoundation
import Observation
import SwiftUI
import CompositionKit

/// Screen state and user intents for the camera. Owns the capture, analysis and
/// motion services; the views only read state and call intents.
@MainActor
@Observable
final class CameraViewModel {
    enum Status: Equatable {
        case idle, needsPermission, denied, unavailable, running, failed
    }

    struct Toast: Equatable, Identifiable {
        let id = UUID()
        let key: String
        var opensSettings = false
    }

    private(set) var status: Status = .idle
    private(set) var guide: GuideFrame = .empty
    private(set) var imageSize = CGSize(width: 3, height: 4)
    private(set) var configuration: CameraConfiguration?
    private(set) var motionState = MotionManager.Snapshot()
    private(set) var lastThumbnail: UIImage?
    private(set) var lastPhoto: UIImage?
    private(set) var isCapturing = false
    private(set) var captureFlash = false
    var toast: Toast?
    var flash: FlashMode = .auto

    let settings: AppSettings
    let camera = CameraManager()
    private let motion = MotionManager()
    private let pipeline: CompositionPipeline
    private let haptics = HapticManager()
    private var toastTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
        pipeline = CompositionPipeline(motion: motion)
        if !settings.availableModes.contains(settings.mode) { settings.mode = .portrait }

        let pipeline = pipeline
        camera.onFrame = { @Sendable buffer in pipeline.process(buffer) }
        pipeline.onGuide = { @Sendable [weak self] frame, size in
            MainActor.assumeIsolated { self?.apply(frame, size: size) }
        }
        motion.onUpdate = { @Sendable [weak self] snapshot in
            MainActor.assumeIsolated { self?.motionState = snapshot }
        }
        syncPipeline()
    }

    var mode: CompositionMode { settings.mode }

    // MARK: Lifecycle

    func start() async {
        switch CameraManager.authorization {
        case .notDetermined:
            status = .needsPermission
            return
        case .denied, .restricted:
            status = .denied
            return
        case .authorized:
            break
        @unknown default:
            status = .denied
            return
        }
        guard CameraManager.hasAnyCamera else {
            status = .unavailable
            return
        }
        if configuration == nil {
            handle(await camera.configure())
        }
        guard status == .running || configuration != nil else { return }
        haptics.prepare()
        motion.start()
        camera.start()
        status = .running
    }

    func stop() {
        camera.stop()
        motion.stop()
    }

    func requestPermission() async {
        _ = await CameraManager.requestAccess()
        await start()
    }

    // MARK: Intents

    func setMode(_ mode: CompositionMode) {
        guard mode != settings.mode, settings.availableModes.contains(mode) else { return }
        settings.mode = mode
        haptics.selection()
        guide = .empty
        syncPipeline()
    }

    func shiftMode(by offset: Int) {
        let modes = settings.availableModes
        guard let i = modes.firstIndex(of: settings.mode) else { return }
        let next = i + offset
        guard modes.indices.contains(next) else { return }
        setMode(modes[next])
    }

    func settingsChanged() {
        if !settings.availableModes.contains(settings.mode) { settings.mode = .portrait }
        haptics.isEnabled = settings.haptics
        syncPipeline()
    }

    func select(_ lens: LensOption) {
        guard lens != configuration?.selectedLens else { return }
        configuration?.selectedLens = lens
        haptics.selection()
        camera.select(lens)
    }

    func cycleFlash() {
        flash = flash.next
        haptics.selection()
    }

    func switchCamera() async {
        guide = .empty
        handle(await camera.switchCamera())
    }

    func capture() {
        guard status == .running, !isCapturing else { return }
        isCapturing = true
        haptics.shutter()
        let saveToPhotos = settings.saveToPhotos
        camera.capturePhoto(flash: configuration?.supportsFlash == true ? flash : .off,
                            preferHEIF: settings.preferHEIF,
                            willCapture: { [weak self] in
                                DispatchQueue.main.async { MainActor.assumeIsolated { self?.flashScreen() } }
                            },
                            completion: { [weak self] result in
                                DispatchQueue.main.async {
                                    MainActor.assumeIsolated { self?.finishCapture(result, save: saveToPhotos) }
                                }
                            })
    }

    // MARK: Private

    private func apply(_ frame: GuideFrame, size: CGSize) {
        imageSize = size
        guide = frame
        if frame.didBecomeOptimal, settings.showGuide { haptics.optimalReached() }
    }

    private func syncPipeline() {
        let mode = settings.mode
        let enabled = settings.showGuide || settings.showTips || settings.showScore
        pipeline.update { $0.mode = mode; $0.isEnabled = enabled }
        haptics.isEnabled = settings.haptics
        if !enabled { guide = .empty }
    }

    private func handle(_ result: CameraSetupResult) {
        switch result {
        case .success(let config):
            configuration = config
            if status != .running { status = .running }
        case .notAuthorized: status = .denied
        case .unavailable: status = .unavailable
        case .failed: status = .failed
        }
    }

    private func flashScreen() {
        captureFlash = true
        withAnimation(.easeOut(duration: 0.25)) { captureFlash = false }
    }

    private func finishCapture(_ result: Result<Data, Error>, save: Bool) {
        isCapturing = false
        guard case .success(let data) = result else {
            showToast("toast.capture_failed")
            return
        }
        if let image = UIImage(data: data) {
            lastPhoto = image
            lastThumbnail = image.preparingThumbnail(of: CGSize(width: 120, height: 120)) ?? image
        }
        guard save else { return }
        Task {
            do {
                try await PhotoLibrarySaver.save(data)
                showToast("toast.saved")
            } catch PhotoLibrarySaver.SaveError.denied {
                showToast("toast.photos_denied", opensSettings: true)
            } catch {
                showToast("toast.save_failed")
            }
        }
    }

    private func showToast(_ key: String, opensSettings: Bool = false) {
        toastTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { toast = Toast(key: key, opensSettings: opensSettings) }
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(opensSettings ? 3.5 : 1.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.25)) { self?.toast = nil }
        }
    }
}
