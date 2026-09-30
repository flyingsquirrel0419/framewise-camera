import Foundation
import Observation
import CompositionKit

/// User preferences, persisted in UserDefaults.
@MainActor
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var showGuide: Bool { didSet { save(showGuide, .showGuide) } }
    var showTarget: Bool { didSet { save(showTarget, .showTarget) } }
    var showTips: Bool { didSet { save(showTips, .showTips) } }
    var showScore: Bool { didSet { save(showScore, .showScore) } }
    var haptics: Bool { didSet { save(haptics, .haptics) } }
    var showGrid: Bool { didSet { save(showGrid, .showGrid) } }
    var showLevel: Bool { didSet { save(showLevel, .showLevel) } }
    var autoScene: Bool { didSet { save(autoScene, .autoScene) } }
    var saveToPhotos: Bool { didSet { save(saveToPhotos, .saveToPhotos) } }
    var preferHEIF: Bool { didSet { save(preferHEIF, .preferHEIF) } }
    var mode: CompositionMode { didSet { defaults.set(mode.rawValue, forKey: Key.mode.rawValue) } }

    private enum Key: String {
        case showGuide, showTarget, showTips, showScore, haptics, showGrid, showLevel
        case autoScene, saveToPhotos, preferHEIF, mode
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func bool(_ key: Key, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key.rawValue) as? Bool ?? fallback
        }
        showGuide = bool(.showGuide, true)
        showTarget = bool(.showTarget, true)
        showTips = bool(.showTips, true)
        showScore = bool(.showScore, false)
        haptics = bool(.haptics, true)
        showGrid = bool(.showGrid, false)
        showLevel = bool(.showLevel, true)
        autoScene = bool(.autoScene, true)
        saveToPhotos = bool(.saveToPhotos, true)
        preferHEIF = bool(.preferHEIF, true)
        mode = defaults.string(forKey: Key.mode.rawValue).flatMap(CompositionMode.init(rawValue:)) ?? .auto
    }

    /// Modes offered in the selector. AUTO disappears when automatic scene
    /// detection is turned off.
    var availableModes: [CompositionMode] {
        autoScene ? CompositionMode.allCases : CompositionMode.allCases.filter { $0 != .auto }
    }

    private func save(_ value: Bool, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }
}
