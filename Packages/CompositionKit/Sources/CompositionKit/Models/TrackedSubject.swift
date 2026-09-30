import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A candidate subject with an ID that stays stable across frames, so the user
/// can tap it and the guide keeps following it.
public struct TrackedSubject: Equatable, Sendable, Identifiable {
    public var id: Int
    /// `.person`, `.pet` or `.object`.
    public var kind: SubjectKind
    public var rect: CGRect
    public var confidence: Float
    /// Present for people, used to resolve eye line / facing when selected.
    public var person: PersonObservation?

    public init(id: Int, kind: SubjectKind, rect: CGRect, confidence: Float, person: PersonObservation? = nil) {
        self.id = id
        self.kind = kind
        self.rect = rect
        self.confidence = confidence
        self.person = person
    }
}
