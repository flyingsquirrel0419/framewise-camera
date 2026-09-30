import Vision
import CompositionKit

/// Full-body human rectangles (Vision's on-device human detector).
final class HumanDetector {
    let request: VNDetectHumanRectanglesRequest = {
        let r = VNDetectHumanRectanglesRequest()
        r.upperBodyOnly = false
        return r
    }()

    func bodies() -> [BodyInput] {
        (request.results ?? []).map {
            BodyInput(rect: $0.boundingBox.flippedVertically, confidence: $0.confidence)
        }
    }
}
