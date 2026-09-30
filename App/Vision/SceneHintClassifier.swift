import Vision
import CompositionKit

/// Whole-frame image classification (Vision's on-device taxonomy) reduced to
/// the few hints the style recommender needs: food, nature, golden hour, night.
final class SceneHintClassifier {
    let request = VNClassifyImageRequest()

    func hints() -> SceneHints {
        let labels = (request.results ?? []).prefix(40).map { (identifier: $0.identifier, confidence: $0.confidence) }
        return SceneHints.from(labels: Array(labels))
    }
}
