import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Single person: thirds (or centered when facing the camera), headroom,
/// looking room and edge tension.
public struct PortraitCompositionRule: CompositionRule {
    public init() {}

    public func evaluate(_ placed: PlacedSubject, subject: ResolvedSubject, observation: SceneObservation) -> ScoreBreakdown {
        let facingStrength = subject.facing.map { min(abs($0) / 0.35, 1) } ?? 0
        // A frontal subject can sit dead center; a profile wants the thirds.
        let centerAffinity = 0.9 - 0.3 * Double(facingStrength)
        let thirds = RuleLibrary.verticalThirdLine(placed.keyPoint.x)
        let center = RuleLibrary.centered(placed.keyPoint.x) * centerAffinity
        let eyeLine = gaussian(abs(placed.keyPoint.y - 1.0 / 3.0), sigma: 0.1)

        var components = [
            thirds >= center
                ? RuleScore(id: .thirds, weight: 0.32, value: thirds)
                : RuleScore(id: .center, weight: 0.32, value: center),
            RuleScore(id: .eyeLine, weight: 0.12, value: eyeLine),
            RuleScore(id: .edge, weight: 0.14, value: RuleLibrary.edgeTension(placed.rect, ignoreBottom: true))
        ]
        if let top = placed.headTop {
            components.append(RuleScore(id: .headroom, weight: 0.22,
                                        value: RuleLibrary.headroom(headTop: top, subjectHeight: placed.rect.height)))
        }
        if let facing = subject.facing, facingStrength > 0.3 {
            components.append(RuleScore(id: .lookingRoom, weight: 0.3 * Double(facingStrength),
                                        value: RuleLibrary.lookingRoom(keyX: placed.keyPoint.x, facing: facing)))
        }
        return ScoreBreakdown(components: components)
    }
}

/// Several people: keep the group balanced around the center, eye line near the
/// upper third, nobody cut at the edges.
public struct GroupCompositionRule: CompositionRule {
    public init() {}

    public func evaluate(_ placed: PlacedSubject, subject: ResolvedSubject, observation: SceneObservation) -> ScoreBreakdown {
        let centered = RuleLibrary.centered(placed.rect.midX, sigma: 0.08)
        let thirds = RuleLibrary.verticalThirdLine(placed.rect.midX) * 0.75
        var components = [
            centered >= thirds
                ? RuleScore(id: .groupBalance, weight: 0.34, value: centered)
                : RuleScore(id: .thirds, weight: 0.34, value: thirds),
            RuleScore(id: .eyeLine, weight: 0.18, value: gaussian(abs(placed.keyPoint.y - 1.0 / 3.0), sigma: 0.11)),
            RuleScore(id: .edge, weight: 0.26, value: RuleLibrary.edgeTension(placed.rect, ignoreBottom: true))
        ]
        if let top = placed.headTop {
            components.append(RuleScore(id: .headroom, weight: 0.2,
                                        value: RuleLibrary.headroom(headTop: top, subjectHeight: placed.rect.height)))
        }
        return ScoreBreakdown(components: components)
    }
}
