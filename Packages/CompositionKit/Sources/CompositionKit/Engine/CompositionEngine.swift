import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Entry point: observation in, stabilized guide out.
///
/// Pipeline: scene classification (with hysteresis) → subject resolution →
/// candidate scoring → temporal stabilization. Not thread-safe; call from one queue.
public final class CompositionEngine {
    private let recommender = RecommendationEngine()
    private let stabilizer: GuideStabilizer
    private let tracker = SubjectTracker()
    private var styles = StyleRecommender()
    private var selection: SubjectSelection = .automatic
    private var scene: SceneType?
    private var pendingScene: SceneType?
    private var pendingCount = 0
    private var mode: CompositionMode?
    private var previousSubject: CGRect?

    /// Frames a new AUTO scene must persist before the engine switches to it.
    public var sceneSwitchFrames = 4

    public init(config: StabilizerConfig = StabilizerConfig()) {
        stabilizer = GuideStabilizer(config: config)
    }

    public var currentScene: SceneType? { scene }

    public func reset() {
        stabilizer.reset()
        tracker.reset()
        styles.reset()
        selection = .automatic
        scene = nil
        pendingScene = nil
        pendingCount = 0
        previousSubject = nil
    }

    public func process(_ observation: SceneObservation, mode: CompositionMode,
                        selection requested: SubjectSelection = .automatic, time: TimeInterval) -> GuideFrame {
        if mode != self.mode {
            self.mode = mode
            reset()
        }
        let visible = tracker.update(observation, time: time)

        if requested != selection {
            selection = requested
            stabilizer.snapToNextSubject()
            previousSubject = nil
            styles.reset() // a deliberate pick changes the look right away
        }

        var frame: GuideFrame
        var selectionLost = false
        if case .manual(let id) = selection {
            if let tracked = tracker.subject(id: id) {
                let subject = SubjectResolver.resolve(tracked: tracked, observation: observation)
                previousSubject = subject.rect
                let rec = recommender.recommend(for: subject, observation: observation)
                frame = stabilizer.update(rec, missingTip: .searching, observation: observation, time: time)
                frame.result?.subjectID = id
                frame.selectedID = id
            } else {
                // The picked subject left the frame: fall back to automatic.
                selectionLost = true
                selection = .automatic
                stabilizer.snapToNextSubject()
                frame = processAutomatic(observation, mode: mode, visible: visible, time: time)
            }
        } else {
            frame = processAutomatic(observation, mode: mode, visible: visible, time: time)
        }

        frame.subjects = visible
        frame.selectionLost = selectionLost
        frame.recommendedStyle = styles.update(kind: frame.result?.subjectKind, hints: observation.hints, time: time)
        return frame
    }

    private func processAutomatic(_ observation: SceneObservation, mode: CompositionMode,
                                  visible: [TrackedSubject], time: TimeInterval) -> GuideFrame {
        let rawScene = SceneClassifier.scene(for: mode, observation: observation)
        let activeScene = stableScene(rawScene)

        var resolution = SubjectResolver.resolve(scene: activeScene, observation: observation, previous: previousSubject)
        if case .missing = resolution, activeScene != rawScene {
            // The sticky scene lost its subject; follow the raw scene immediately.
            scene = rawScene
            pendingScene = nil
            pendingCount = 0
            stabilizer.resetTarget()
            resolution = SubjectResolver.resolve(scene: rawScene, observation: observation, previous: previousSubject)
        }

        switch resolution {
        case .subject(let subject):
            previousSubject = subject.rect
            let rec = recommender.recommend(for: subject, observation: observation)
            var frame = stabilizer.update(rec, missingTip: .searching, observation: observation, time: time)
            if subject.kind != .group, subject.kind != .scene {
                frame.result?.subjectID = tracker.bestMatch(for: subject.rect, in: visible)?.id
            }
            return frame
        case .missing(let tip):
            previousSubject = nil
            return stabilizer.update(nil, missingTip: tip, observation: observation, time: time)
        }
    }

    private func stableScene(_ raw: SceneType) -> SceneType {
        guard let current = scene else {
            scene = raw
            return raw
        }
        if raw == current {
            pendingScene = nil
            pendingCount = 0
            return current
        }
        if raw == pendingScene {
            pendingCount += 1
        } else {
            pendingScene = raw
            pendingCount = 1
        }
        if pendingCount >= sceneSwitchFrames {
            scene = raw
            pendingScene = nil
            pendingCount = 0
            stabilizer.resetTarget()
            return raw
        }
        return current
    }
}
