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
    /// Manually tapped subject, if any.
    private(set) var selectedID: Int?
    /// The style currently applied to preview and photos.
    private(set) var activeStyle: PhotoStyle = .natural
    /// Tap-to-focus marker (normalized preview point).
    private(set) var focusMarker: FocusMarker?

    struct FocusMarker: Equatable, Identifiable {
        let id = UUID()
        let point: CGPoint
    }

    let settings: AppSettings
    let camera = CameraManager()
    let renderer = FilteredPreviewRenderer()
    private let motion = MotionManager()
    private let pipeline: CompositionPipeline
    private let haptics = HapticManager()
    private var toastTask: Task<Void, Never>?
    private var lastFocusPoint: CGPoint?
    private var lastFocusTime: Date = .distantPast
    private var manualFocusUntil: Date = .distantPast

    init(settings: AppSettings) {
        self.settings = settings
        pipeline = CompositionPipeline(motion: motion)
        if !settings.availableModes.contains(settings.mode) { settings.mode = .portrait }

        let pipeline = pipeline, renderer = renderer
        camera.onFrame = { @Sendable buffer in
            renderer.render(buffer)
            pipeline.process(buffer)
        }
        pipeline.onGuide = { @Sendable [weak self] frame, size in
            MainActor.assumeIsolated { self?.apply(frame, size: size) }
        }
        motion.onUpdate = { @Sendable [weak self] snapshot in
            MainActor.assumeIsolated { self?.motionState = snapshot }
        }
        syncPipeline()
        applyStyle(settings.fixedStyle ?? .natural)
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
        clearSelection()
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

    /// Tap on the preview: select a subject, or focus on an empty spot.
    func tap(at point: CGPoint, subjectID: Int?) {
        if let id = subjectID {
            if id == selectedID {
                clearSelection()
            } else {
                selectedID = id
                pipeline.update { $0.selection = .manual(id) }
                haptics.selection()
                focus(at: point, manual: false)
            }
        } else {
            clearSelection()
            focus(at: point, manual: true)
            withAnimation(.easeOut(duration: 0.2)) { focusMarker = FocusMarker(point: point) }
            let marker = focusMarker
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.2))
                guard let self, self.focusMarker == marker else { return }
                withAnimation(.easeIn(duration: 0.3)) { self.focusMarker = nil }
            }
        }
    }

    func clearSelection() {
        guard selectedID != nil else { return }
        selectedID = nil
        pipeline.update { $0.selection = .automatic }
    }

    func setStyleChoice(_ choice: String) {
        settings.styleChoice = choice
        haptics.selection()
        applyStyle(settings.fixedStyle ?? guide.recommendedStyle)
    }

    func cycleFlash() {
        flash = flash.next
        haptics.selection()
    }

    func switchCamera() async {
        clearSelection()
        guide = .empty
        handle(await camera.switchCamera())
    }

    func capture() {
        guard status == .running, !isCapturing else { return }
        isCapturing = true
        haptics.shutter()
        let saveToPhotos = settings.saveToPhotos
        let style = activeStyle.parameters
        let preferHEIF = settings.preferHEIF
        camera.capturePhoto(flash: configuration?.supportsFlash == true ? flash : .off,
                            preferHEIF: preferHEIF,
                            willCapture: { [weak self] in
                                DispatchQueue.main.async { MainActor.assumeIsolated { self?.flashScreen() } }
                            },
                            completion: { [weak self] result in
                                DispatchQueue.main.async {
                                    MainActor.assumeIsolated {
                                        self?.finishCapture(result, style: style, preferHEIF: preferHEIF, save: saveToPhotos)
                                    }
                                }
                            })
    }

    // MARK: Private

    private func apply(_ frame: GuideFrame, size: CGSize) {
        imageSize = size
        guide = frame
        if frame.didBecomeOptimal, settings.showGuide { haptics.optimalReached() }
        if frame.selectionLost, selectedID != nil {
            selectedID = nil
            showToast("toast.selection_lost")
        }
        applyStyle(settings.fixedStyle ?? frame.recommendedStyle)
        followSubjectFocus(frame.result)
    }

    private func applyStyle(_ style: PhotoStyle) {
        guard style != activeStyle else { return }
        activeStyle = style
        renderer.setStyle(style.parameters)
    }

    /// Keeps focus/exposure on the subject's eyes (or center) as it moves,
    /// throttled so the lens isn't constantly re-targeted.
    private func followSubjectFocus(_ result: CompositionResult?) {
        guard settings.autoFocusSubject, !isCapturing, Date() > manualFocusUntil else { return }
        let now = Date()
        guard let point = result?.focusPoint else {
            if lastFocusPoint != nil, now.timeIntervalSince(lastFocusTime) > 1.5 {
                lastFocusPoint = nil
                camera.focus(at: CGPoint(x: 0.5, y: 0.5))
            }
            return
        }
        let moved = lastFocusPoint.map { hypot($0.x - point.x, $0.y - point.y) } ?? 1
        let elapsed = now.timeIntervalSince(lastFocusTime)
        if moved > 0.05 || (moved > 0.015 && elapsed > 0.8) {
            focus(at: point, manual: false)
        }
    }

    private func focus(at point: CGPoint, manual: Bool) {
        camera.focus(at: point)
        lastFocusPoint = point
        lastFocusTime = Date()
        if manual { manualFocusUntil = Date().addingTimeInterval(4) }
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

    private func finishCapture(_ result: Result<Data, Error>, style: StyleParameters, preferHEIF: Bool, save: Bool) {
        isCapturing = false
        guard case .success(let original) = result else {
            showToast("toast.capture_failed")
            return
        }
        Task {
            let data = await Task.detached(priority: .userInitiated) {
                PhotoStyler.apply(style, to: original, preferHEIF: preferHEIF)
            }.value
            store(data, save: save)
        }
    }

    private func store(_ data: Data, save: Bool) {
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
