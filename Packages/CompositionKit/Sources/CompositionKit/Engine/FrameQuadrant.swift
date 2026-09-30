import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// How the phone is held relative to the portrait-locked screen. Analysis runs
/// in "photo space" (upright for the photo being taken); the overlay draws in
/// screen space. Both are normalized, top-left origin.
public enum FrameQuadrant: String, Equatable, Sendable {
    case portrait
    /// Gravity points toward the screen's right edge (photo top = screen left).
    case gravityRight
    /// Gravity points toward the screen's left edge (photo top = screen right).
    case gravityLeft

    /// Rotation to apply to screen-space UI so it reads upright to the user.
    public var uiRotationDegrees: Double {
        switch self {
        case .portrait: return 0
        case .gravityRight: return -90
        case .gravityLeft: return 90
        }
    }

    public func toPhoto(_ s: CGPoint) -> CGPoint {
        switch self {
        case .portrait: return s
        case .gravityRight: return CGPoint(x: 1 - s.y, y: s.x)
        case .gravityLeft: return CGPoint(x: s.y, y: 1 - s.x)
        }
    }

    public func toScreen(_ p: CGPoint) -> CGPoint {
        switch self {
        case .portrait: return p
        case .gravityRight: return CGPoint(x: p.y, y: 1 - p.x)
        case .gravityLeft: return CGPoint(x: 1 - p.y, y: p.x)
        }
    }

    public func toScreen(_ r: CGRect) -> CGRect { map(r, toScreen) }
    public func toPhoto(_ r: CGRect) -> CGRect { map(r, toPhoto) }

    private func map(_ r: CGRect, _ f: (CGPoint) -> CGPoint) -> CGRect {
        guard self != .portrait else { return r }
        let a = f(CGPoint(x: r.minX, y: r.minY)), b = f(CGPoint(x: r.maxX, y: r.maxY))
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    /// Quadrant from a screen-plane gravity angle (radians; 0 = portrait,
    /// positive = gravity toward the screen's right), with hysteresis.
    public static func from(angle: Double, current: FrameQuadrant) -> FrameQuadrant {
        let deg = angle * 180 / .pi
        let centers: [(FrameQuadrant, Double)] = [(.portrait, 0), (.gravityRight, 90), (.gravityLeft, -90)]
        if let c = centers.first(where: { $0.0 == current }), abs(deg - c.1) < 55 { return current }
        if abs(deg) <= 45 { return .portrait }
        if deg > 45 && deg <= 135 { return .gravityRight }
        if deg < -45 && deg >= -135 { return .gravityLeft }
        return current // upside down: keep the last orientation
    }

    /// Deviation from level for this quadrant, in radians.
    public func levelDeviation(angle: Double) -> Double {
        switch self {
        case .portrait: return angle
        case .gravityRight: return angle - .pi / 2
        case .gravityLeft: return angle + .pi / 2
        }
    }
}

public extension CompositionResult {
    /// Converts the geometry from photo space to screen space for drawing.
    func toScreen(_ q: FrameQuadrant) -> CompositionResult {
        guard q != .portrait else { return self }
        var r = self
        r.subjectRect = q.toScreen(subjectRect)
        r.targetRect = q.toScreen(targetRect)
        r.subjectCenter = q.toScreen(subjectCenter)
        r.targetCenter = q.toScreen(targetCenter)
        return r
    }
}
