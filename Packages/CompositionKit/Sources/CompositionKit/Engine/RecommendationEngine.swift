import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public enum SizeAdvice: Equatable, Sendable {
    case closer(scale: CGFloat)
    case farther(scale: CGFloat)

    public var scale: CGFloat {
        switch self {
        case .closer(let s), .farther(let s): return s
        }
    }
}

public struct Candidate: Equatable, Sendable {
    public var anchor: AnchorID
    public var placed: PlacedSubject
    public var breakdown: ScoreBreakdown
    /// Composition score minus movement cost (plus a bonus for staying put).
    public var value: Double
    public var moveDistance: CGFloat
}

public struct Recommendation: Equatable, Sendable {
    public var subject: ResolvedSubject
    public var candidates: [Candidate]
    public var sizeAdvice: SizeAdvice?
    public var needsLevel: Bool
    /// 0...1 quality of the current framing.
    public var currentScore: Double

    public var best: Candidate { candidates.max { $0.value < $1.value }! }
    public var current: Candidate { candidate(for: .current)! }

    public func candidate(for anchor: AnchorID) -> Candidate? {
        candidates.first { $0.anchor == anchor }
    }
}

/// Scores every candidate position for a subject and recommends the best one.
public struct RecommendationEngine: Sendable {
    public var stayBonus: Double = 0.035
    public var moveCost: Double = 0.12

    private let rules: [SceneType: any CompositionRule] = [
        .portrait: PortraitCompositionRule(),
        .group: GroupCompositionRule(),
        .object: ObjectCompositionRule(),
        .landscape: LandscapeCompositionRule()
    ]

    public init() {}

    public func recommend(for subject: ResolvedSubject, observation: SceneObservation) -> Recommendation {
        let rule = rules[subject.scene]!
        let candidates = CandidateGenerator.anchors(for: subject).map { anchor, point -> Candidate in
            let placed = PlacedSubject.place(subject, at: point)
            let breakdown = rule.evaluate(placed, subject: subject, observation: observation)
            let distance = subject.keyPoint.distance(to: placed.keyPoint)
            var value = breakdown.total - moveCost * Double(distance)
            if anchor == .current { value += stayBonus }
            return Candidate(anchor: anchor, placed: placed, breakdown: breakdown, value: value, moveDistance: distance)
        }

        let size = sizeAdvice(for: subject)
        let level = needsLevel(scene: subject.scene, roll: observation.deviceRoll)
        let current = candidates.first { $0.anchor == .current }!
        var score = current.breakdown.total
        if size != nil { score *= 0.78 }
        if subject.scene != .landscape { score *= 0.85 + 0.15 * RuleLibrary.horizon(roll: observation.deviceRoll) }

        return Recommendation(subject: subject, candidates: candidates, sizeAdvice: size,
                              needsLevel: level, currentScore: clamp(score, 0, 1))
    }

    func sizeAdvice(for s: ResolvedSubject) -> SizeAdvice? {
        let r = s.rect
        switch s.scene {
        case .portrait:
            let face = s.faceHeight ?? 0
            if face > 0.46 || (r.height >= 0.97 && r.width >= 0.9) { return .farther(scale: 0.75) }
            if r.height < 0.26 && r.area < 0.045 { return .closer(scale: min(1.7, 0.42 / max(r.height, 0.05))) }
        case .group:
            if r.width > 0.97 { return .farther(scale: 0.82) }
            if r.width < 0.34 && r.height < 0.38 { return .closer(scale: min(1.6, 0.5 / max(r.width, 0.05))) }
        case .object:
            if r.area > 0.55 || r.width > 0.95 || r.height > 0.95 { return .farther(scale: 0.75) }
            if r.area < 0.025 { return .closer(scale: min(1.8, sqrt(0.08 / max(r.area, 0.004)))) }
        case .landscape:
            break
        }
        return nil
    }

    func needsLevel(scene: SceneType, roll: Double?) -> Bool {
        guard let roll else { return false }
        let degrees = abs(roll) * 180 / .pi
        return scene == .landscape ? degrees > 2.5 : degrees > 7
    }

    /// The single most important reason the target is better than the current framing.
    public static func reason(from current: Candidate, to target: Candidate, subject: ResolvedSubject,
                              observation: SceneObservation) -> GuideReason? {
        var best: (RuleID, Double)?
        for t in target.breakdown.components {
            let c = current.breakdown.value(of: t.id) ?? 0
            let gain = t.weight * (t.value - c)
            if gain > 0.01, gain > (best?.1 ?? 0) { best = (t.id, gain) }
        }
        guard let id = best?.0 else { return nil }
        switch id {
        case .thirds, .eyeLine: return .thirds
        case .center:
            return (observation.saliency?.horizontalSymmetry ?? 0) > 0.72 ? .symmetry : .centered
        case .headroom:
            let top = current.placed.headTop ?? 0.1
            return top < 0.035 ? .headroomTight : .headroomLoose
        case .lookingRoom: return .lookingRoom
        case .edge: return .edgeTension
        case .balance: return .balance
        case .groupBalance: return .groupBalance
        case .negativeSpace: return .negativeSpace
        case .foreground: return .foreground
        case .horizon: return .horizon
        }
    }
}
