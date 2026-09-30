import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Generates the positions a subject could be moved to. Anchors other than
/// `.current` are absolute frame positions (or keep the current vertical
/// position), so a locked target never chases the subject.
public enum CandidateGenerator {
    public static func anchors(for subject: ResolvedSubject) -> [(AnchorID, CGPoint)] {
        let k = subject.keyPoint
        let t: CGFloat = 1.0 / 3.0
        var anchors: [(AnchorID, CGPoint)] = [
            (.current, k),
            (.thirdLineLeft, CGPoint(x: t, y: k.y)),
            (.thirdLineRight, CGPoint(x: 1 - t, y: k.y)),
            (.nudgeLeft, CGPoint(x: 0.42, y: k.y)),
            (.nudgeRight, CGPoint(x: 0.58, y: k.y))
        ]
        switch subject.scene {
        case .portrait, .group:
            // For people, the key point is the eye line, which belongs on the upper third.
            anchors += [
                (.thirdTopLeft, CGPoint(x: t, y: t)),
                (.thirdTopRight, CGPoint(x: 1 - t, y: t)),
                (.centerUpper, CGPoint(x: 0.5, y: t)),
                (.center, CGPoint(x: 0.5, y: k.y))
            ]
        case .object, .landscape:
            anchors += [
                (.thirdTopLeft, CGPoint(x: t, y: t)),
                (.thirdTopRight, CGPoint(x: 1 - t, y: t)),
                (.thirdBottomLeft, CGPoint(x: t, y: 1 - t)),
                (.thirdBottomRight, CGPoint(x: 1 - t, y: 1 - t)),
                (.center, CGPoint(x: 0.5, y: 0.5)),
                (.centerUpper, CGPoint(x: 0.5, y: k.y))
            ]
        }
        return anchors
    }
}
