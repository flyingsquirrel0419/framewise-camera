import Foundation

/// Picks a look for the current subject and scene, and only changes it after
/// the new choice has been stable for `holdTime`, so the preview never flickers
/// between filters.
public struct StyleRecommender: Sendable {
    public var holdTime: TimeInterval = 1.0
    public private(set) var current: PhotoStyle = .natural
    private var pending: PhotoStyle?
    private var pendingSince: TimeInterval = 0
    private var hasValue = false

    public init() {}

    public static func style(for kind: SubjectKind?, hints: SceneHints) -> PhotoStyle {
        if hints.isFood, kind != .person, kind != .group { return .food }
        switch kind {
        case .person: return .warm
        case .group: return .bright
        case .pet: return .vivid
        case .object: return hints.isFood ? .food : .vivid
        case .scene, nil:
            if hints.isGoldenHour { return .golden }
            if hints.isNature || kind == .scene { return .landscape }
            return .natural
        }
    }

    public mutating func update(kind: SubjectKind?, hints: SceneHints, time: TimeInterval) -> PhotoStyle {
        let wanted = Self.style(for: kind, hints: hints)
        guard hasValue else {
            hasValue = true
            current = wanted
            return wanted
        }
        if wanted == current {
            pending = nil
        } else if wanted != pending {
            pending = wanted
            pendingSince = time
        } else if time - pendingSince >= holdTime {
            current = wanted
            pending = nil
        }
        return current
    }

    public mutating func reset() {
        hasValue = false
        pending = nil
        current = .natural
    }
}
