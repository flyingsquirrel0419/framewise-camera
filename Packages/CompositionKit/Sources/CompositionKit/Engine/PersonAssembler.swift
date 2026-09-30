import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Raw face data from the vision layer (normalized, top-left origin).
public struct FaceInput: Equatable, Sendable {
    public var rect: CGRect
    public var eyeCenter: CGPoint?
    public var facing: CGFloat?
    public var confidence: Float
    public init(rect: CGRect, eyeCenter: CGPoint? = nil, facing: CGFloat? = nil, confidence: Float = 1) {
        self.rect = rect
        self.eyeCenter = eyeCenter
        self.facing = facing
        self.confidence = confidence
    }
}

public struct BodyInput: Equatable, Sendable {
    public var rect: CGRect
    public var confidence: Float
    public init(rect: CGRect, confidence: Float = 1) {
        self.rect = rect
        self.confidence = confidence
    }
}

/// Pairs detected faces with detected bodies so each person is reported once.
public enum PersonAssembler {
    public static func assemble(bodies: [BodyInput], faces: [FaceInput],
                                minBodyConfidence: Float = 0.35) -> [PersonObservation] {
        let validBodies = bodies.filter { $0.confidence >= minBodyConfidence && $0.rect.area > 0.002 }
        var usedFaces = Set<Int>()
        var people: [PersonObservation] = []

        for body in validBodies {
            // A face belongs to a body when it sits inside the body's upper half.
            var bestIndex: Int?
            var bestScore: CGFloat = 0
            for (i, face) in faces.enumerated() where !usedFaces.contains(i) {
                let upper = CGRect(x: body.rect.minX, y: body.rect.minY - body.rect.height * 0.1,
                                   width: body.rect.width, height: body.rect.height * 0.6)
                let inter = upper.intersection(face.rect)
                guard !inter.isNull, face.rect.area > 0 else { continue }
                let coverage = inter.area / face.rect.area
                if coverage > 0.6 && coverage > bestScore {
                    bestScore = coverage
                    bestIndex = i
                }
            }
            var person = PersonObservation(bodyRect: body.rect, confidence: body.confidence)
            if let i = bestIndex {
                usedFaces.insert(i)
                person.faceRect = faces[i].rect
                person.eyeCenter = faces[i].eyeCenter
                person.facing = faces[i].facing
            }
            people.append(person)
        }

        // Faces without a body (close-ups, partial occlusion) still count as people.
        for (i, face) in faces.enumerated() where !usedFaces.contains(i) && face.rect.area > 0.001 {
            people.append(PersonObservation(faceRect: face.rect, eyeCenter: face.eyeCenter,
                                            facing: face.facing, confidence: face.confidence))
        }
        return people
    }
}
