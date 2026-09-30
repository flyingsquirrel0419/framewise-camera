import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public enum CompositionMode: String, CaseIterable, Codable, Sendable {
    case auto, portrait, object, landscape
}

public enum SceneType: String, Equatable, Sendable {
    case portrait, group, object, landscape
}

public enum SubjectKind: String, Equatable, Sendable, CaseIterable {
    case person, group, pet, object, scene
}

/// Which subject the guide is built around.
public enum SubjectSelection: Equatable, Sendable {
    /// The engine picks the subject for the current mode.
    case automatic
    /// The user tapped a tracked subject.
    case manual(Int)
}

public enum GuideDirection: String, Equatable, Sendable, CaseIterable {
    case none
    case left, right, up, down
    case upLeft, upRight, downLeft, downRight
    case closer, farther

    /// Unit vector in normalized top-left space for planar directions.
    public var vector: CGVector {
        switch self {
        case .left: return CGVector(dx: -1, dy: 0)
        case .right: return CGVector(dx: 1, dy: 0)
        case .up: return CGVector(dx: 0, dy: -1)
        case .down: return CGVector(dx: 0, dy: 1)
        case .upLeft: return CGVector(dx: -0.707, dy: -0.707)
        case .upRight: return CGVector(dx: 0.707, dy: -0.707)
        case .downLeft: return CGVector(dx: -0.707, dy: 0.707)
        case .downRight: return CGVector(dx: 0.707, dy: 0.707)
        case .none, .closer, .farther: return .zero
        }
    }

    /// Classifies a displacement. Diagonals are used only when both axes matter.
    public static func from(_ delta: CGVector, deadZone: CGFloat = 0.001) -> GuideDirection {
        let ax = abs(delta.dx), ay = abs(delta.dy)
        guard max(ax, ay) > deadZone else { return .none }
        let diagonal = min(ax, ay) > max(ax, ay) * 0.45
        if diagonal {
            switch (delta.dx > 0, delta.dy > 0) {
            case (true, true): return .downRight
            case (true, false): return .upRight
            case (false, true): return .downLeft
            case (false, false): return .upLeft
            }
        }
        if ax >= ay { return delta.dx > 0 ? .right : .left }
        return delta.dy > 0 ? .down : .up
    }
}

public enum MoveMagnitude: String, Equatable, Sendable {
    case small, medium, large

    public static func from(distance: CGFloat) -> MoveMagnitude {
        if distance < 0.09 { return .small }
        if distance < 0.2 { return .medium }
        return .large
    }
}

/// A single actionable instruction. The app maps each case to a localization key.
public enum GuideTip: Equatable, Sendable {
    /// Move the subject within the frame (people / objects).
    case moveSubject(GuideDirection, MoveMagnitude)
    /// Pan/tilt the camera (landscapes, where there is no movable subject).
    case panCamera(GuideDirection, MoveMagnitude)
    case moveCloser
    case moveBack
    case levelHorizon
    case goodComposition
    case searching
    case findPerson
    case findObject
}

/// Optional one-line "why" shown under the tip.
public enum GuideReason: String, Equatable, Sendable {
    case thirds
    case headroomTight = "headroom_tight"
    case headroomLoose = "headroom_loose"
    case lookingRoom = "looking_room"
    case edgeTension = "edge_tension"
    case centered
    case symmetry
    case balance
    case negativeSpace = "negative_space"
    case foreground
    case groupBalance = "group_balance"
    case horizon
}

/// Identifies which candidate position a recommendation came from, so the
/// stabilizer can apply hysteresis per candidate.
public enum AnchorID: String, Equatable, Hashable, Sendable {
    case current
    case thirdTopLeft, thirdTopRight, thirdBottomLeft, thirdBottomRight
    case thirdLineLeft, thirdLineRight
    case center, centerUpper
    case nudgeLeft, nudgeRight, nudgeUp, nudgeDown
}

public struct CompositionResult: Equatable, Sendable {
    public var scene: SceneType
    public var subjectKind: SubjectKind
    public var subjectRect: CGRect
    public var subjectCenter: CGPoint
    public var targetRect: CGRect
    public var targetCenter: CGPoint
    public var direction: GuideDirection
    public var magnitude: MoveMagnitude
    public var distance: CGFloat
    public var score: Int
    public var tip: GuideTip
    public var reason: GuideReason?
    public var isOptimal: Bool
    public var anchor: AnchorID
    /// Where focus/exposure should go: the eyes for people, the center otherwise.
    /// `nil` for landscapes.
    public var focusPoint: CGPoint?
    /// Tracker ID of the primary subject, when it maps to a single tracked subject.
    public var subjectID: Int?

    public init(scene: SceneType, subjectKind: SubjectKind, subjectRect: CGRect, subjectCenter: CGPoint,
                targetRect: CGRect, targetCenter: CGPoint, direction: GuideDirection,
                magnitude: MoveMagnitude, distance: CGFloat, score: Int, tip: GuideTip,
                reason: GuideReason?, isOptimal: Bool, anchor: AnchorID,
                focusPoint: CGPoint? = nil, subjectID: Int? = nil) {
        self.scene = scene
        self.subjectKind = subjectKind
        self.subjectRect = subjectRect
        self.subjectCenter = subjectCenter
        self.targetRect = targetRect
        self.targetCenter = targetCenter
        self.direction = direction
        self.magnitude = magnitude
        self.distance = distance
        self.score = score
        self.tip = tip
        self.reason = reason
        self.isOptimal = isOptimal
        self.anchor = anchor
        self.focusPoint = focusPoint
        self.subjectID = subjectID
    }
}
