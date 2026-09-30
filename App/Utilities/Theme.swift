import SwiftUI

/// Premium dark palette: near-black surfaces, a single warm amber accent.
enum Theme {
    static let amber = Color(red: 1.0, green: 0.74, blue: 0.40)
    static let background = Color(red: 0.03, green: 0.03, blue: 0.035)
    static let charcoal = Color(white: 0.12)
    static let hairline = Color.white.opacity(0.14)
    static let textPrimary = Color.white.opacity(0.9)
    static let textSecondary = Color.white.opacity(0.56)

    static let guideLine: CGFloat = 1.2
    static let smooth = Animation.smooth(duration: 0.28)
}
