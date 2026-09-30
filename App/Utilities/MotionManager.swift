import CoreMotion
import CompositionKit
import os

/// Reads device gravity to derive how the phone is held and how far it is from level.
/// Thread-safe snapshot for the analysis queue; main-thread callback for the UI.
final class MotionManager: @unchecked Sendable {
    struct Snapshot: Equatable, Sendable {
        var quadrant: FrameQuadrant = .portrait
        /// Radians from level; nil when the phone lies flat.
        var levelDeviation: Double?
    }

    private let motion = CMMotionManager()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "motion"
        q.maxConcurrentOperationCount = 1
        return q
    }()
    private let state = OSAllocatedUnfairLock(initialState: Snapshot())
    private var lastPublish: TimeInterval = 0

    /// Called on the main queue at up to ~15 Hz.
    var onUpdate: ((Snapshot) -> Void)?

    var snapshot: Snapshot { state.withLock { $0 } }

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(to: queue) { [weak self] data, _ in
            guard let self, let g = data?.gravity else { return }
            self.handle(gravity: g, time: data?.timestamp ?? 0)
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }

    private func handle(gravity g: CMAcceleration, time: TimeInterval) {
        let isFlat = abs(g.z) > 0.82
        let angle = atan2(g.x, -g.y)
        let snap: Snapshot = state.withLock { s in
            if !isFlat {
                s.quadrant = FrameQuadrant.from(angle: angle, current: s.quadrant)
                s.levelDeviation = s.quadrant.levelDeviation(angle: angle)
            } else {
                s.levelDeviation = nil
            }
            return s
        }
        guard time - lastPublish > 1.0 / 15.0 else { return }
        lastPublish = time
        DispatchQueue.main.async { [weak self] in self?.onUpdate?(snap) }
    }
}
