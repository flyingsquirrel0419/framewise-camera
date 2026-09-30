import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Landscapes: place the main area of interest on the thirds, or center it when
/// the scene is strongly symmetric; keep some foreground weight; level horizon.
public struct LandscapeCompositionRule: CompositionRule {
    public init() {}

    public func evaluate(_ placed: PlacedSubject, subject: ResolvedSubject, observation: SceneObservation) -> ScoreBreakdown {
        let symmetry = observation.saliency?.horizontalSymmetry ?? 0
        let centerAffinity = 0.5 + 0.5 * symmetry
        let thirds = RuleLibrary.thirds(placed.keyPoint, horizontalWeight: 0.5, sigma: 0.09)
        let center = RuleLibrary.centered(placed.keyPoint.x, sigma: 0.07) * centerAffinity

        // Foreground: interest sitting on the lower or upper third line reads as
        // deliberate; floating in the exact middle band reads as undecided.
        let vertical = RuleLibrary.thirdLines.map { abs(placed.keyPoint.y - $0) }.min()!
        let foreground = gaussian(vertical, sigma: 0.12)

        return ScoreBreakdown(components: [
            thirds >= center
                ? RuleScore(id: .thirds, weight: 0.45, value: thirds)
                : RuleScore(id: .center, weight: 0.45, value: center),
            RuleScore(id: .foreground, weight: 0.2, value: foreground),
            RuleScore(id: .edge, weight: 0.1, value: RuleLibrary.edgeTension(placed.rect)),
            RuleScore(id: .horizon, weight: 0.25, value: RuleLibrary.horizon(roll: observation.deviceRoll))
        ])
    }
}
