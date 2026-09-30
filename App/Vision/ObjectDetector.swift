import Vision
import CompositionKit

/// Class-agnostic object detection via Vision's objectness-based saliency model.
/// It finds "things" (products, food, pets, plants) without a bundled model.
final class ObjectDetector {
    let request = VNGenerateObjectnessBasedSaliencyImageRequest()

    func objects() -> [SalientObject] {
        guard let observation = request.results?.first else { return [] }
        return (observation.salientObjects ?? []).map {
            SalientObject(rect: $0.boundingBox.flippedVertically, confidence: $0.confidence)
        }
    }
}
