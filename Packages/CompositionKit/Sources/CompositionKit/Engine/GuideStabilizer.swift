import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// What the UI should show for one analyzed frame.
public struct GuideFrame: Equatable, Sendable {
    public var result: CompositionResult?
    public var tip: GuideTip
    public var reason: GuideReason?
    /// True only on the frame where the framing becomes optimal (for haptics).
    public var didBecomeOptimal: Bool
    /// Every candidate subject in view, with stable IDs (for colored boxes and tapping).
    public var subjects: [TrackedSubject] = []
    /// The active manual selection, if any.
    public var selectedID: Int?
    /// True when a manually selected subject disappeared and the engine fell back to automatic.
    public var selectionLost = false
    /// Stabilized automatic style recommendation.
    public var recommendedStyle: PhotoStyle = .natural

    public init(result: CompositionResult?, tip: GuideTip, reason: GuideReason?, didBecomeOptimal: Bool) {
        self.result = result
        self.tip = tip
        self.reason = reason
        self.didBecomeOptimal = didBecomeOptimal
    }

    public static let empty = GuideFrame(result: nil, tip: .searching, reason: nil, didBecomeOptimal: false)
}

public struct StabilizerConfig: Sendable {
    /// A new target must beat the locked one by this much...
    public var switchMargin: Double = 0.06
    /// ...for this many consecutive frames before the guide moves.
    public var switchFrames: Int = 4
    /// Enter/exit distances for the optimal state (hysteresis band).
    public var optimalEnter: CGFloat = 0.035
    public var optimalExit: CGFloat = 0.07
    /// How long the last guide is held when the subject is briefly lost.
    public var lostTimeout: TimeInterval = 0.7
    public init() {}
}

/// Turns noisy per-frame recommendations into a calm, consistent guide:
/// EMA smoothing, target hysteresis, optimal-state hysteresis and tip debouncing.
/// Not thread-safe; drive it from a single queue.
public final class GuideStabilizer {
    public var config: StabilizerConfig

    private var subject = RectSmoother(minAlpha: 0.22, maxAlpha: 0.7, fastMotion: 0.12)
    private var target = RectSmoother(minAlpha: 0.18, maxAlpha: 0.45, fastMotion: 0.2)
    private var score = ScalarSmoother(alpha: 0.15)
    private var tips = TipFilter()
    private var lockedAnchor: AnchorID?
    private var challenger: AnchorID?
    private var challengerCount = 0
    private var isOptimal = false
    private var lastSeen: TimeInterval?
    private var lastFrame: GuideFrame = .empty
    private var lastSubjectKind: SubjectKind?

    public init(config: StabilizerConfig = StabilizerConfig()) {
        self.config = config
    }

    public var lockedAnchorForTesting: AnchorID? { lockedAnchor }

    public func reset() {
        subject.reset()
        target.reset()
        score.reset()
        tips.reset()
        resetTarget()
        isOptimal = false
        lastSeen = nil
        lastFrame = .empty
        lastSubjectKind = nil
    }

    /// Forget the locked target (e.g. after a scene or mode change).
    public func resetTarget() {
        lockedAnchor = nil
        challenger = nil
        challengerCount = 0
    }

    /// Snap smoothing to the new subject immediately (after a manual selection).
    public func snapToNextSubject() {
        subject.reset()
        target.reset()
        resetTarget()
        isOptimal = false
    }

    public func update(_ rec: Recommendation?, missingTip: GuideTip, observation: SceneObservation,
                       time: TimeInterval) -> GuideFrame {
        guard let rec else {
            if let seen = lastSeen, time - seen < config.lostTimeout, lastFrame.result != nil {
                var held = lastFrame
                held.didBecomeOptimal = false
                return held
            }
            reset()
            let tip = tips.update(missingTip, reason: nil, time: time)
            lastFrame = GuideFrame(result: nil, tip: tip, reason: nil, didBecomeOptimal: false)
            return lastFrame
        }
        lastSeen = time

        if lastSubjectKind != rec.subject.kind {
            resetTarget()
            isOptimal = false
            lastSubjectKind = rec.subject.kind
        }

        // Subject smoothing; snap when the subject jumps somewhere unrelated.
        let raw = rec.subject.rect
        if let prev = subject.value, prev.iou(raw) == 0, prev.center.distance(to: raw.center) > 0.25 {
            subject.snap(to: raw)
            target.reset()
            resetTarget()
        }
        let smoothSubject = subject.update(raw)

        let chosen = chooseTarget(rec)
        var rawTarget = chosen.placed.rect
        if let size = rec.sizeAdvice {
            let k = chosen.placed.keyPoint
            let scaled = CGRect(x: k.x - (k.x - rawTarget.minX) * size.scale,
                                y: k.y - (k.y - rawTarget.minY) * size.scale,
                                width: rawTarget.width * size.scale,
                                height: rawTarget.height * size.scale)
            rawTarget = scaled.clampedInside()
        }

        // Optimal state with an enter/exit band so it doesn't toggle at the boundary.
        let distance = smoothSubject.center.distance(to: rawTarget.center)
        let wasOptimal = isOptimal
        if rec.sizeAdvice != nil {
            isOptimal = false
        } else if isOptimal {
            isOptimal = distance < config.optimalExit
        } else {
            isOptimal = distance < config.optimalEnter || chosen.anchor == .current
        }
        // When optimal, the recommended box merges into the subject box.
        let smoothTarget = target.update(isOptimal ? smoothSubject : rawTarget)

        let delta = smoothSubject.center.vector(to: rawTarget.center)
        let direction = GuideDirection.from(delta, deadZone: 0.01)
        let magnitude = MoveMagnitude.from(distance: delta.length)
        let smoothScore = score.update(rec.currentScore)

        let rawTip: GuideTip
        if rec.needsLevel && (rec.subject.scene == .landscape || isOptimal) {
            rawTip = .levelHorizon
        } else if let size = rec.sizeAdvice {
            if case .closer = size { rawTip = .moveCloser } else { rawTip = .moveBack }
        } else if isOptimal || direction == .none {
            rawTip = .goodComposition
        } else if rec.subject.scene == .landscape {
            // No movable subject: turn the camera the opposite way.
            rawTip = .panCamera(direction.opposite, magnitude)
        } else {
            rawTip = .moveSubject(direction, magnitude)
        }

        let reason: GuideReason? = {
            if rawTip == .levelHorizon { return .horizon }
            guard !isOptimal else { return nil }
            return RecommendationEngine.reason(from: rec.current, to: chosen, subject: rec.subject,
                                               observation: observation)
        }()
        let tip = tips.update(rawTip, reason: reason, time: time)

        let result = CompositionResult(
            scene: rec.subject.scene,
            subjectKind: rec.subject.kind,
            subjectRect: smoothSubject,
            subjectCenter: smoothSubject.center,
            targetRect: smoothTarget,
            targetCenter: smoothTarget.center,
            direction: isOptimal ? .none : (rec.sizeAdvice.map { if case .closer = $0 { return .closer } else { return .farther } } ?? direction),
            magnitude: magnitude,
            distance: isOptimal ? 0 : distance,
            score: Int((smoothScore * 100).rounded()),
            tip: tip,
            reason: tips.displayedReason,
            isOptimal: isOptimal,
            anchor: chosen.anchor,
            focusPoint: rec.subject.scene == .landscape ? nil : rec.subject.keyPoint
        )
        lastFrame = GuideFrame(result: result, tip: tip, reason: tips.displayedReason,
                               didBecomeOptimal: isOptimal && !wasOptimal)
        return lastFrame
    }

    /// Target hysteresis: keep the locked anchor unless another one is clearly
    /// better for several consecutive frames.
    private func chooseTarget(_ rec: Recommendation) -> Candidate {
        let best = rec.best
        guard let locked = lockedAnchor, let lockedCandidate = rec.candidate(for: locked) else {
            lockedAnchor = best.anchor
            challenger = nil
            challengerCount = 0
            return best
        }
        if best.anchor == locked || best.value - lockedCandidate.value <= config.switchMargin {
            challenger = nil
            challengerCount = 0
            return lockedCandidate
        }
        if challenger == best.anchor {
            challengerCount += 1
        } else {
            challenger = best.anchor
            challengerCount = 1
        }
        if challengerCount >= config.switchFrames {
            lockedAnchor = best.anchor
            challenger = nil
            challengerCount = 0
            return best
        }
        return lockedCandidate
    }
}

public extension GuideDirection {
    var opposite: GuideDirection {
        switch self {
        case .left: return .right
        case .right: return .left
        case .up: return .down
        case .down: return .up
        case .upLeft: return .downRight
        case .upRight: return .downLeft
        case .downLeft: return .upRight
        case .downRight: return .upLeft
        case .closer: return .farther
        case .farther: return .closer
        case .none: return .none
        }
    }
}
