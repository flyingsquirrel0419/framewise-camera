import Vision
import CompositionKit

/// Cats and dogs via Vision's built-in animal recognizer.
final class AnimalDetector {
    let request = VNRecognizeAnimalsRequest()

    func animals() -> [AnimalObservation] {
        (request.results ?? []).compactMap { obs in
            guard obs.confidence > 0.4 else { return nil }
            return AnimalObservation(rect: obs.boundingBox.flippedVertically,
                                     label: obs.labels.first?.identifier ?? "animal",
                                     confidence: obs.confidence)
        }
    }
}
