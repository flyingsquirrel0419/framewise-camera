import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Products, food, things: thirds power points or a clean centered product shot,
/// negative space and balance against other salient objects.
public struct ObjectCompositionRule: CompositionRule {
    public init() {}

    public func evaluate(_ placed: PlacedSubject, subject: ResolvedSubject, observation: SceneObservation) -> ScoreBreakdown {
        let symmetry = observation.saliency?.horizontalSymmetry ?? 0.5
        let isolated = subject.secondaryMass == nil
        // A lone, symmetric object reads well centered (product shot).
        let centerAffinity = min(1.0, 0.7 + 0.2 * symmetry + (isolated ? 0.12 : 0))
        let thirds = RuleLibrary.thirds(placed.keyPoint, horizontalWeight: 0.55)
        let center = gaussian(placed.keyPoint.distance(to: CGPoint(x: 0.5, y: 0.5)), sigma: 0.07) * centerAffinity

        var components = [
            thirds >= center
                ? RuleScore(id: .thirds, weight: 0.42, value: thirds)
                : RuleScore(id: .center, weight: 0.42, value: center),
            RuleScore(id: .negativeSpace, weight: 0.18, value: RuleLibrary.negativeSpace(placed.rect)),
            RuleScore(id: .edge, weight: 0.2, value: RuleLibrary.edgeTension(placed.rect))
        ]
        if subject.secondaryMass != nil {
            components.append(RuleScore(id: .balance, weight: 0.2,
                                        value: RuleLibrary.balance(subject: placed.rect, secondary: subject.secondaryMass)))
        }
        return ScoreBreakdown(components: components)
    }
}
