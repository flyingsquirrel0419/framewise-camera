import SwiftUI
import CompositionKit

/// Premium dark palette: near-black surfaces, a single warm amber accent.
enum Theme {
    static let amber = Color(red: 1.0, green: 0.74, blue: 0.40)
    static let background = Color(red: 0.03, green: 0.03, blue: 0.035)
    static let charcoal = Color(white: 0.12)
    static let hairline = Color.white.opacity(0.14)
    static let textPrimary = Color.white.opacity(0.9)
    static let textSecondary = Color.white.opacity(0.56)

    /// Muted per-kind tints so candidates are distinguishable without neon.
    static let personTint = amber
    static let petTint = Color(red: 0.97, green: 0.60, blue: 0.56)
    static let objectTint = Color(red: 0.52, green: 0.83, blue: 0.79)
    static let sceneTint = Color(red: 0.92, green: 0.90, blue: 0.84)

    static func tint(for kind: SubjectKind) -> Color {
        switch kind {
        case .person, .group: return personTint
        case .pet: return petTint
        case .object: return objectTint
        case .scene: return sceneTint
        }
    }

    static let guideLine: CGFloat = 1.2
    static let smooth = Animation.smooth(duration: 0.28)
}
