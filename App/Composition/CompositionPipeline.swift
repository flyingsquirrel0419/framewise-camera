import CoreVideo
import ImageIO
import QuartzCore
import CompositionKit
import os

/// Glue between frames and the engine. Runs entirely on the camera's video
/// queue, throttled to an adaptive analysis rate (5–15 fps) that is independent
/// of the 30 fps preview and of UI animation.
final class CompositionPipeline: @unchecked Sendable {
    struct Config: Sendable {
        var mode: CompositionMode = .auto
        var isEnabled = true
    }

    /// Delivered on the main queue, already converted to screen space.
    var onGuide: ((GuideFrame, CGSize) -> Void)?

    private let analyzer = VisionAnalyzer()
    private let engine = CompositionEngine()
    private let motion: MotionManager
    private let config = OSAllocatedUnfairLock(initialState: Config())
    private var lastRun: CFTimeInterval = 0
    private var interval: CFTimeInterval = 1.0 / 12.0
    private var lastQuadrant: FrameQuadrant = .portrait

    init(motion: MotionManager) {
        self.motion = motion
    }

    func update(_ change: @Sendable (inout Config) -> Void) {
        config.withLock { change(&$0) }
    }

    /// Called on the video queue for every frame; most frames return immediately.
    func process(_ pixelBuffer: CVPixelBuffer) {
        let now = CACurrentMediaTime()
        guard now - lastRun >= interval else { return }
        lastRun = now
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
        var frame = engine.process(observation, mode: cfg.mode, time: now)
        frame.result = frame.result?.toScreen(quadrant)
        adaptRate(cost: CACurrentMediaTime() - now)

        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        DispatchQueue.main.async { [weak self] in self?.onGuide?(frame, size) }
    }

    /// Back off when analysis is slow or the device is hot; speed up when there's headroom.
    private func adaptRate(cost: CFTimeInterval) {
        let thermal = ProcessInfo.processInfo.thermalState
        let floor: CFTimeInterval = thermal == .serious || thermal == .critical ? 1.0 / 6.0 : 1.0 / 15.0
        let target = max(floor, min(1.0 / 5.0, cost * 1.6))
        interval += (target - interval) * 0.2
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
