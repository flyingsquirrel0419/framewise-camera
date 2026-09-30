import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Exponential moving average for rects with motion-adaptive responsiveness:
/// small jitter is heavily smoothed, deliberate motion is followed quickly.
public struct RectSmoother: Sendable {
    public var minAlpha: CGFloat
    public var maxAlpha: CGFloat
    /// Normalized distance at which `maxAlpha` is reached.
    public var fastMotion: CGFloat
    public private(set) var value: CGRect?

    public init(minAlpha: CGFloat = 0.2, maxAlpha: CGFloat = 0.65, fastMotion: CGFloat = 0.15) {
        self.minAlpha = minAlpha
        self.maxAlpha = maxAlpha
        self.fastMotion = fastMotion
    }

    @discardableResult
    public mutating func update(_ new: CGRect) -> CGRect {
        guard let old = value else {
            value = new
            return new
        }
        let motion = max(old.center.distance(to: new.center), abs(old.width - new.width), abs(old.height - new.height))
        let t = clamp(motion / fastMotion, 0, 1)
        let alpha = minAlpha + (maxAlpha - minAlpha) * t
        let r = CGRect(x: old.minX + (new.minX - old.minX) * alpha,
                       y: old.minY + (new.minY - old.minY) * alpha,
                       width: old.width + (new.width - old.width) * alpha,
                       height: old.height + (new.height - old.height) * alpha)
        value = r
        return r
    }

    public mutating func snap(to rect: CGRect) { value = rect }
    public mutating func reset() { value = nil }
}

public struct ScalarSmoother: Sendable {
    public var alpha: Double
    public private(set) var value: Double?

    public init(alpha: Double) { self.alpha = alpha }

    @discardableResult
    public mutating func update(_ new: Double) -> Double {
        let v = value.map { $0 + (new - $0) * alpha } ?? new
        value = v
        return v
    }

    public mutating func reset() { value = nil }
}

/// Debounces tip changes so the text never flickers between instructions.
public struct TipFilter: Sendable {
    public var hold: TimeInterval
    public var fastHold: TimeInterval
    public private(set) var displayed: GuideTip?
    public private(set) var displayedReason: GuideReason?
    private var pending: GuideTip?
    private var pendingSince: TimeInterval = 0

    public init(hold: TimeInterval = 0.45, fastHold: TimeInterval = 0.2) {
        self.hold = hold
        self.fastHold = fastHold
    }

    @discardableResult
    public mutating func update(_ tip: GuideTip, reason: GuideReason?, time: TimeInterval) -> GuideTip {
        guard let current = displayed else {
            displayed = tip
            displayedReason = reason
            return tip
        }
        if tip == current {
            pending = nil
            if displayedReason == nil { displayedReason = reason }
            return current
        }
        if tip != pending {
            pending = tip
            pendingSince = time
        }
        let required = tip == .goodComposition ? fastHold : hold
        if time - pendingSince >= required {
            displayed = tip
            displayedReason = reason
            pending = nil
        }
        return displayed!
    }

    public mutating func reset() {
        displayed = nil
        displayedReason = nil
        pending = nil
    }
}
