import UIKit

/// Light, non-repeating haptics.
@MainActor
final class HapticManager {
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private var lastOptimal: Date = .distantPast
    var isEnabled = true

    func prepare() {
        soft.prepare()
        rigid.prepare()
    }

    /// Fires once when the framing becomes optimal; ignores re-entries within the cooldown.
    func optimalReached() {
        guard isEnabled, Date().timeIntervalSince(lastOptimal) > 1.5 else { return }
        lastOptimal = Date()
        soft.impactOccurred(intensity: 0.75)
        soft.prepare()
    }

    func shutter() {
        guard isEnabled else { return }
        rigid.impactOccurred(intensity: 0.6)
        rigid.prepare()
    }

    func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
