import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Identifies an individual rule so the engine can explain its recommendation.
public enum RuleID: String, Equatable, Sendable {
    case thirds, center, headroom, lookingRoom, edge, balance, negativeSpace
    case eyeLine, groupBalance, horizon, foreground
}

public struct RuleScore: Equatable, Sendable {
    public var id: RuleID
    public var weight: Double
    public var value: Double
}

public struct ScoreBreakdown: Equatable, Sendable {
    public var components: [RuleScore]

    public var total: Double {
        let w = components.reduce(0) { $0 + $1.weight }
        guard w > 0 else { return 0 }
        return components.reduce(0) { $0 + $1.weight * $1.value } / w
    }

    public func value(of id: RuleID) -> Double? {
        components.first { $0.id == id }?.value
    }
}

/// A subject placed at a candidate position.
public struct PlacedSubject: Equatable, Sendable {
    public var rect: CGRect
    public var keyPoint: CGPoint
    public var headTop: CGFloat?

    /// Moves the subject so its key point lands on `anchor`, keeping it in frame.
    public static func place(_ subject: ResolvedSubject, at anchor: CGPoint) -> PlacedSubject {
        let delta = subject.keyPoint.vector(to: anchor)
        let moved = subject.rect.translated(by: delta)
        let clamped = moved.clampedInside()
        let applied = CGVector(dx: delta.dx + (clamped.minX - moved.minX),
                               dy: delta.dy + (clamped.minY - moved.minY))
        return PlacedSubject(rect: clamped,
                             keyPoint: CGPoint(x: subject.keyPoint.x + applied.dx, y: subject.keyPoint.y + applied.dy),
                             headTop: subject.headTop.map { $0 + applied.dy })
    }
}

/// A scene-specific scoring strategy that combines several composition rules.
public protocol CompositionRule: Sendable {
    func evaluate(_ placed: PlacedSubject, subject: ResolvedSubject, observation: SceneObservation) -> ScoreBreakdown
}

/// Building blocks shared by the scene rules. Every function returns a value in [0, 1].
public enum RuleLibrary {
    static let thirdLines: [CGFloat] = [1.0 / 3.0, 2.0 / 3.0]

    /// Rule of thirds for a point: horizontal and vertical proximity to the thirds grid.
    public static func thirds(_ p: CGPoint, horizontalWeight: Double = 0.6, sigma: CGFloat = 0.075) -> Double {
        let dx = thirdLines.map { abs(p.x - $0) }.min()!
        let dy = thirdLines.map { abs(p.y - $0) }.min()!
        return horizontalWeight * gaussian(dx, sigma: sigma) + (1 - horizontalWeight) * gaussian(dy, sigma: sigma)
    }

    /// Horizontal proximity to one of the vertical thirds lines only.
    public static func verticalThirdLine(_ x: CGFloat, sigma: CGFloat = 0.07) -> Double {
        gaussian(thirdLines.map { abs(x - $0) }.min()!, sigma: sigma)
    }

    public static func centered(_ x: CGFloat, sigma: CGFloat = 0.06) -> Double {
        gaussian(abs(x - 0.5), sigma: sigma)
    }

    /// Headroom: gap between the top of the head and the top of the frame.
    /// Tight shots want less room than wide ones.
    public static func headroom(headTop: CGFloat, subjectHeight: CGFloat) -> Double {
        let tight = subjectHeight > 0.75
        return trapezoid(headTop,
                         low: tight ? -0.04 : -0.005,
                         idealLow: tight ? 0.0 : 0.035,
                         idealHigh: tight ? 0.08 : 0.15,
                         high: tight ? 0.2 : 0.32)
    }

    /// Looking room: more space in front of the subject's face than behind it.
    public static func lookingRoom(keyX: CGFloat, facing: CGFloat) -> Double {
        let ahead = facing > 0 ? 1 - keyX : keyX
        let behind = 1 - ahead
        let x = Double((ahead - behind) / 0.12)
        return 1 / (1 + exp(-x))
    }

    /// Penalizes edges that nearly touch the frame border ("tangents") and
    /// subjects cut off by the frame. `ignoreBottom` is for people, whose legs
    /// are often intentionally cropped.
    public static func edgeTension(_ r: CGRect, ignoreBottom: Bool = false) -> Double {
        var score = 1.0
        let margins: [(CGFloat, Bool)] = [
            (r.minX, r.width < 0.98),
            (1 - r.maxX, r.width < 0.98),
            (r.minY, r.height < 0.98),
            (ignoreBottom ? 1 : 1 - r.maxY, r.height < 0.98)
        ]
        for (m, applicable) in margins where applicable {
            if m < 0 { score *= 0.55 }           // cut off
            else if m < 0.02 { score *= 0.72 }   // tangent
            else if m < 0.04 { score *= 0.9 }
        }
        return score
    }

    /// Visual balance between the subject and other salient mass.
    public static func balance(subject: CGRect, secondary: (point: CGPoint, weight: CGFloat)?) -> Double {
        guard let s = secondary else { return 1 }
        let total = subject.area + s.weight
        guard total > 0 else { return 1 }
        let cx = (subject.midX * subject.area + s.point.x * s.weight) / total
        return gaussian(abs(cx - 0.5), sigma: 0.14)
    }

    /// Room around an object: neither cramped nor lost in empty space.
    public static func negativeSpace(_ r: CGRect) -> Double {
        let minMargin = min(r.minX, r.minY, 1 - r.maxX, 1 - r.maxY)
        return trapezoid(minMargin, low: -0.02, idealLow: 0.06, idealHigh: 0.45, high: 0.5)
    }

    /// Level horizon score from device roll (radians).
    public static func horizon(roll: Double?) -> Double {
        guard let roll else { return 1 }
        let degrees = abs(roll) * 180 / .pi
        return gaussian(CGFloat(degrees), sigma: 5)
    }
}
