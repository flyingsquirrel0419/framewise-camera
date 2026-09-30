import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#else
/// swift-corelibs-foundation has no CGVector; mirror the CoreGraphics API on Linux.
public struct CGVector: Equatable, Sendable {
    public var dx: CGFloat
    public var dy: CGFloat
    public init(dx: CGFloat, dy: CGFloat) {
        self.dx = dx
        self.dy = dy
    }
    public static let zero = CGVector(dx: 0, dy: 0)
}
#endif

/// All CompositionKit geometry lives in a normalized, top-left-origin space
/// where the full frame is `CGRect(x: 0, y: 0, width: 1, height: 1)`.
public enum NormalizedSpace {
    public static let frame = CGRect(x: 0, y: 0, width: 1, height: 1)
}

public extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
    var area: CGFloat { max(0, width) * max(0, height) }

    func iou(_ other: CGRect) -> CGFloat {
        let inter = intersection(other)
        guard !inter.isNull, inter.area > 0 else { return 0 }
        let union = area + other.area - inter.area
        return union > 0 ? inter.area / union : 0
    }

    func translated(by delta: CGVector) -> CGRect {
        offsetBy(dx: delta.dx, dy: delta.dy)
    }

    /// Scales around the center.
    func scaled(by factor: CGFloat) -> CGRect {
        let w = width * factor, h = height * factor
        return CGRect(x: midX - w / 2, y: midY - h / 2, width: w, height: h)
    }

    /// Shifts the rect so it lies inside `bounds` where possible. Dimensions that
    /// exceed the bounds are centered instead of clipped.
    func clampedInside(_ bounds: CGRect = NormalizedSpace.frame) -> CGRect {
        var r = self
        if r.width >= bounds.width {
            r.origin.x = bounds.midX - r.width / 2
        } else {
            r.origin.x = min(max(r.minX, bounds.minX), bounds.maxX - r.width)
        }
        if r.height >= bounds.height {
            r.origin.y = bounds.midY - r.height / 2
        } else {
            r.origin.y = min(max(r.minY, bounds.minY), bounds.maxY - r.height)
        }
        return r
    }

    /// Converts a Vision-style (bottom-left origin) normalized rect to top-left origin.
    var flippedVertically: CGRect {
        CGRect(x: minX, y: 1 - maxY, width: width, height: height)
    }

    static func union(of rects: [CGRect]) -> CGRect? {
        guard var result = rects.first else { return nil }
        for r in rects.dropFirst() { result = result.union(r) }
        return result
    }
}

public extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }

    func vector(to other: CGPoint) -> CGVector {
        CGVector(dx: other.x - x, dy: other.y - y)
    }

    var flippedVertically: CGPoint { CGPoint(x: x, y: 1 - y) }
}

public extension CGVector {
    var length: CGFloat { hypot(dx, dy) }
}

@inlinable
func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
    min(max(value, lower), upper)
}

/// Gaussian falloff in [0, 1]: 1 at distance 0, ~0.37 at `sigma`.
@inlinable
func gaussian(_ distance: CGFloat, sigma: CGFloat) -> Double {
    Double(exp(-(distance * distance) / (sigma * sigma)))
}

/// Trapezoid score: 1 inside [idealLow, idealHigh], linear falloff to 0 at [low, high].
func trapezoid(_ value: CGFloat, low: CGFloat, idealLow: CGFloat, idealHigh: CGFloat, high: CGFloat) -> Double {
    if value >= idealLow && value <= idealHigh { return 1 }
    if value < idealLow {
        guard idealLow > low else { return 0 }
        return Double(clamp((value - low) / (idealLow - low), 0, 1))
    }
    guard high > idealHigh else { return 0 }
    return Double(clamp((high - value) / (high - idealHigh), 0, 1))
}
