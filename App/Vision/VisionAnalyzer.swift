import Vision
import ImageIO
import CompositionKit

/// Runs the on-device Vision requests for one frame and assembles a
/// `SceneObservation`. Requests are created once and reused. Heavier requests
/// run on a subset of frames depending on the mode; their last results are
/// reused in between. Not thread-safe: call from the video queue only.
final class VisionAnalyzer {
    private let humans = HumanDetector()
    private let faces = FaceDetector()
    private let objects = ObjectDetector()
    private let saliency = SaliencyAnalyzer()

    private var tick = 0
    private var cachedObjects: [SalientObject] = []
    private var cachedSaliency: SaliencySummary?
    private var lastPeopleCount = 0

    func reset() {
        tick = 0
        cachedObjects = []
        cachedSaliency = nil
        lastPeopleCount = 0
    }

    func analyze(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                 mode: CompositionMode, roll: Double?, time: TimeInterval) -> SceneObservation {
        tick &+= 1
        let wantsPeople = mode == .auto || mode == .portrait
        let peopleLikely = wantsPeople && lastPeopleCount > 0
        let wantsObjects = mode == .object || (mode == .auto && !peopleLikely)
        let wantsSaliency = mode == .landscape || mode == .object || (mode == .auto && !peopleLikely)

        var requests: [VNRequest] = []
        if wantsPeople { requests += [humans.request, faces.request] }
        let runObjects = wantsObjects && (mode == .object || tick % 2 == 0)
        if runObjects { requests.append(objects.request) }
        let runSaliency = wantsSaliency && (mode == .landscape ? tick % 2 == 1 : tick % 3 == 1)
        if runSaliency { requests.append(saliency.request) }
        if !wantsObjects { cachedObjects = [] }
        if !wantsSaliency { cachedSaliency = nil }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform(requests)
        } catch {
            return SceneObservation(deviceRoll: roll, timestamp: time)
        }

        var people: [PersonObservation] = []
        if wantsPeople {
            people = PersonAssembler.assemble(bodies: humans.bodies(), faces: faces.faces())
            lastPeopleCount = people.count
        } else {
            lastPeopleCount = 0
        }
        if runObjects { cachedObjects = objects.objects() }
        if runSaliency { cachedSaliency = saliency.summary() }

        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let rotated = orientation == .left || orientation == .right
        let aspect = rotated ? height / max(width, 1) : width / max(height, 1)
        return SceneObservation(people: people, salientObjects: cachedObjects, saliency: cachedSaliency,
                                deviceRoll: roll, frameAspect: aspect, timestamp: time)
    }
}
