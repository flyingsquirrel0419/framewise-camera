import Vision
import ImageIO
import CompositionKit

/// Runs the on-device Vision requests for one frame and assembles a
/// `SceneObservation`. Requests are created once and reused. Heavier requests
/// run on a subset of frames depending on the mode; their last results are
/// reused in between. Not thread-safe: call from the analysis queue only.
final class VisionAnalyzer {
    private let humans = HumanDetector()
    private let faces = FaceDetector()
    private let objects = ObjectDetector()
    private let animals = AnimalDetector()
    private let saliency = SaliencyAnalyzer()
    private let classifier = SceneHintClassifier()

    private var tick = 0
    private var cachedObjects: [SalientObject] = []
    private var cachedAnimals: [AnimalObservation] = []
    private var cachedSaliency: SaliencySummary?
    private var cachedHints = SceneHints()
    private var lastPeopleCount = 0

    func reset() {
        tick = 0
        cachedObjects = []
        cachedAnimals = []
        cachedSaliency = nil
        lastPeopleCount = 0
    }

    func analyze(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                 mode: CompositionMode, roll: Double?, time: TimeInterval) -> SceneObservation {
        tick &+= 1
        let wantsPeople = mode != .landscape
        let peopleInView = wantsPeople && lastPeopleCount > 0
        let wantsThings = mode != .landscape
        let wantsSaliency = mode == .landscape || mode == .object || (mode == .auto && !peopleInView)

        var requests: [VNRequest] = []
        if wantsPeople { requests += [humans.request, faces.request] }
        // Objects and pets are always detected (less often while people are the
        // focus) so every candidate can be shown and tapped.
        let objectEvery = mode == .object ? 1 : (peopleInView ? 3 : 2)
        let runObjects = wantsThings && tick % objectEvery == 0
        if runObjects { requests.append(objects.request) }
        let runAnimals = wantsThings && tick % 3 == 1
        if runAnimals { requests.append(animals.request) }
        let runSaliency = wantsSaliency && (mode == .landscape ? tick % 2 == 1 : tick % 3 == 1)
        if runSaliency { requests.append(saliency.request) }
        let runClassifier = tick % 12 == 2
        if runClassifier { requests.append(classifier.request) }
        if !wantsThings { cachedObjects = []; cachedAnimals = [] }
        if !wantsSaliency { cachedSaliency = nil }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform(requests)
        } catch {
            return SceneObservation(hints: cachedHints, deviceRoll: roll, timestamp: time)
        }

        var people: [PersonObservation] = []
        if requests.contains(where: { $0 === humans.request }) {
            people = PersonAssembler.assemble(bodies: humans.bodies(), faces: faces.faces())
            lastPeopleCount = people.count
        } else if !wantsPeople {
            lastPeopleCount = 0
        }
        if runObjects { cachedObjects = objects.objects() }
        if runAnimals { cachedAnimals = animals.animals() }
        if runSaliency { cachedSaliency = saliency.summary() }
        if runClassifier { cachedHints = classifier.hints() }

        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let rotated = orientation == .left || orientation == .right
        let aspect = rotated ? height / max(width, 1) : width / max(height, 1)
        return SceneObservation(people: people, salientObjects: cachedObjects, animals: cachedAnimals,
                                hints: cachedHints, saliency: cachedSaliency, deviceRoll: roll,
                                frameAspect: aspect, timestamp: time)
    }
}
