import Foundation

/// A look applied to the live preview and the saved photo.
public enum PhotoStyle: String, CaseIterable, Codable, Equatable, Sendable {
    case natural, warm, bright, vivid, food, landscape, golden, mono

    public var parameters: StyleParameters {
        switch self {
        case .natural:
            return .natural
        case .warm: // portraits: gentle warmth, soft contrast, lifted shadows
            return StyleParameters(warmth: 0.32, saturation: 1, contrast: 0.97, brightness: 0.01, vibrance: 0.12,
                                   shadows: 0.15, highlights: 0.95, sharpness: 0, vignette: 0.12)
        case .bright: // groups: open, even and clean
            return StyleParameters(warmth: 0.12, saturation: 1, contrast: 1, brightness: 0.035, vibrance: 0.18,
                                   shadows: 0.3, highlights: 0.9, sharpness: 0, vignette: 0)
        case .vivid: // objects and pets: color and crisp detail
            return StyleParameters(warmth: 0.04, saturation: 1.03, contrast: 1.07, brightness: 0, vibrance: 0.38,
                                   shadows: 0.05, highlights: 1, sharpness: 0.35, vignette: 0.1)
        case .food:
            return StyleParameters(warmth: 0.25, saturation: 1.08, contrast: 1.06, brightness: 0.01, vibrance: 0.3,
                                   shadows: 0.1, highlights: 0.95, sharpness: 0.3, vignette: 0.15)
        case .landscape: // depth and clarity, recovered highlights
            return StyleParameters(warmth: -0.05, saturation: 1.02, contrast: 1.08, brightness: 0, vibrance: 0.35,
                                   shadows: 0.35, highlights: 0.85, sharpness: 0.4, vignette: 0)
        case .golden:
            return StyleParameters(warmth: 0.42, saturation: 1.03, contrast: 1.05, brightness: 0, vibrance: 0.3,
                                   shadows: 0.2, highlights: 0.9, sharpness: 0.2, vignette: 0.12)
        case .mono:
            return StyleParameters(warmth: 0, saturation: 0, contrast: 1.12, brightness: 0, vibrance: 0,
                                   shadows: 0.1, highlights: 1, sharpness: 0.2, vignette: 0.2)
        }
    }
}

/// Filter parameters that can be interpolated, so style changes cross-fade.
public struct StyleParameters: Equatable, Sendable {
    /// -1 (cool) ... 1 (warm)
    public var warmth: Double
    /// 1 = neutral
    public var saturation: Double
    /// 1 = neutral
    public var contrast: Double
    /// 0 = neutral
    public var brightness: Double
    /// 0 = neutral
    public var vibrance: Double
    /// Shadow lift, 0 = neutral
    public var shadows: Double
    /// Highlight amount, 1 = neutral
    public var highlights: Double
    public var sharpness: Double
    public var vignette: Double

    public init(warmth: Double, saturation: Double, contrast: Double, brightness: Double, vibrance: Double,
                shadows: Double, highlights: Double, sharpness: Double, vignette: Double) {
        self.warmth = warmth
        self.saturation = saturation
        self.contrast = contrast
        self.brightness = brightness
        self.vibrance = vibrance
        self.shadows = shadows
        self.highlights = highlights
        self.sharpness = sharpness
        self.vignette = vignette
    }

    public static let natural = StyleParameters(warmth: 0, saturation: 1, contrast: 1, brightness: 0, vibrance: 0,
                                                shadows: 0, highlights: 1, sharpness: 0, vignette: 0)

    public var isIdentity: Bool { distance(to: .natural) < 0.002 }

    public func distance(to o: StyleParameters) -> Double {
        [warmth - o.warmth, saturation - o.saturation, contrast - o.contrast, brightness - o.brightness,
         vibrance - o.vibrance, shadows - o.shadows, highlights - o.highlights, sharpness - o.sharpness,
         vignette - o.vignette].map(abs).max() ?? 0
    }

    public static func lerp(_ a: StyleParameters, _ b: StyleParameters, _ t: Double) -> StyleParameters {
        let t = min(max(t, 0), 1)
        func m(_ x: Double, _ y: Double) -> Double { x + (y - x) * t }
        return StyleParameters(warmth: m(a.warmth, b.warmth), saturation: m(a.saturation, b.saturation),
                               contrast: m(a.contrast, b.contrast), brightness: m(a.brightness, b.brightness),
                               vibrance: m(a.vibrance, b.vibrance), shadows: m(a.shadows, b.shadows),
                               highlights: m(a.highlights, b.highlights), sharpness: m(a.sharpness, b.sharpness),
                               vignette: m(a.vignette, b.vignette))
    }
}
