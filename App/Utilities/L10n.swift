import Foundation
import SwiftUI
import CompositionKit

/// Maps engine values to String Catalog keys. No user-facing text is hard-coded;
/// every string lives in Localization/Localizable.xcstrings.
enum L10n {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func tipKey(_ tip: GuideTip, kind: SubjectKind?) -> String {
        switch tip {
        case .moveSubject(let dir, let mag):
            let who = (kind == .object || kind == .pet) ? "object" : "person"
            return "guide.place.\(who).\(dir.keyComponent).\(mag.rawValue)"
        case .panCamera(let dir, let mag):
            return "guide.pan.\(dir.keyComponent).\(mag.rawValue)"
        case .moveCloser: return "guide.move_closer"
        case .moveBack: return "guide.move_back"
        case .levelHorizon: return "guide.level"
        case .goodComposition: return "guide.good_position"
        case .searching: return "guide.searching"
        case .findPerson: return "guide.find_person"
        case .findObject: return "guide.find_object"
        }
    }

    static func reasonKey(_ reason: GuideReason) -> String {
        "reason.\(reason.rawValue)"
    }

    static func subjectLabelKey(_ kind: SubjectKind) -> String {
        "label.\(kind.rawValue)"
    }

    static func styleKey(_ style: PhotoStyle) -> String {
        "style.\(style.rawValue)"
    }

    static func modeKey(_ mode: CompositionMode) -> String {
        "mode.\(mode.rawValue)"
    }
}

extension GuideDirection {
    var keyComponent: String {
        switch self {
        case .upLeft: return "up_left"
        case .upRight: return "up_right"
        case .downLeft: return "down_left"
        case .downRight: return "down_right"
        default: return rawValue
        }
    }
}
