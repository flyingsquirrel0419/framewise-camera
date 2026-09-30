import CoreVideo
import ImageIO
import QuartzCore
import CompositionKit
import os

/// Glue between frames and the engine. Frames arrive on the camera's video
/// queue; analysis runs on its own queue so the (filtered) preview keeps its
/// full frame rate. Only one frame is analyzed at a time and frames arriving in
/// the meantime are dropped, so there is never a backlog. The analysis rate
/// adapts between 5 and 15 fps.
final class CompositionPipeline: @unchecked Sendable {
    struct Config: Sendable {
        var mode: CompositionMode = .auto
        var isEnabled = true
        var selection: SubjectSelection = .automatic
    }

    private struct Timing: Sendable {
        var lastRun: CFTimeInterval = 0
        var interval: CFTimeInterval = 1.0 / 12.0
        var busy = false
    }

    /// Delivered on the main queue, already converted to screen space.
    var onGuide: ((GuideFrame, CGSize) -> Void)?

    private let analysisQueue = DispatchQueue(label: "composition.analysis", qos: .userInitiated)
    private let analyzer = VisionAnalyzer()
    private let engine = CompositionEngine()
    private let motion: MotionManager
    private let config = OSAllocatedUnfairLock(initialState: Config())
    private let timing = OSAllocatedUnfairLock(initialState: Timing())
    private var lastQuadrant: FrameQuadrant = .portrait

    init(motion: MotionManager) {
        self.motion = motion
    }

    func update(_ change: @Sendable (inout Config) -> Void) {
        config.withLock { change(&$0) }
    }

    /// Called on the video queue for every frame; returns immediately.
    func process(_ pixelBuffer: CVPixelBuffer) {
        let now = CACurrentMediaTime()
        let shouldRun = timing.withLock { t -> Bool in
            guard !t.busy, now - t.lastRun >= t.interval else { return false }
            t.busy = true
            t.lastRun = now
            return true
        }
        guard shouldRun else { return }
        analysisQueue.async { [self] in
            analyze(pixelBuffer, time: now)
            timing.withLock { $0.busy = false }
        }
    }

    private func analyze(_ pixelBuffer: CVPixelBuffer, time now: CFTimeInterval) {
        let cfg = config.withLock { $0 }
        guard cfg.isEnabled else { return }

        let motionState = motion.snapshot
        let quadrant = motionState.quadrant
        if quadrant != lastQuadrant {
            lastQuadrant = quadrant
            engine.reset()
            analyzer.reset()
        }

        let observation = analyzer.analyze(pixelBuffer, orientation: quadrant.visionOrientation, mode: cfg.mode,
                                           roll: motionState.levelDeviation, time: now)
        let frame = engine.process(observation, mode: cfg.mode, selection: cfg.selection, time: now).toScreen(quadrant)
        if frame.selectionLost {
            config.withLock { if $0.selection == cfg.selection { $0.selection = .automatic } }
        }
        adaptRate(cost: CACurrentMediaTime() - now)

        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        DispatchQueue.main.async { [weak self] in self?.onGuide?(frame, size) }
    }

    /// Back off when analysis is slow or the device is hot; speed up when there's headroom.
    private func adaptRate(cost: CFTimeInterval) {
        let thermal = ProcessInfo.processInfo.thermalState
        let floor: CFTimeInterval = thermal == .serious || thermal == .critical ? 1.0 / 6.0 : 1.0 / 15.0
        let target = max(floor, min(1.0 / 5.0, cost * 1.6))
        timing.withLock { $0.interval += (target - $0.interval) * 0.2 }
    }
}

extension FrameQuadrant {
    /// Orientation that makes Vision analyze the upright photo, given a portrait buffer.
    var visionOrientation: CGImagePropertyOrientation {
        switch self {
        case .portrait: return .up
        case .gravityRight: return .right
        case .gravityLeft: return .left
        }
    }
}
