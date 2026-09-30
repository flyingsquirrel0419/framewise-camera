import XCTest
@testable import CompositionKit
#if canImport(CoreGraphics)
import CoreGraphics
#endif

final class CompositionEngineTests: XCTestCase {
    // MARK: Helpers

    /// A standing person whose eye line sits at `eyes`.
    func person(eyesAt eyes: CGPoint, height: CGFloat = 0.6, facing: CGFloat? = nil) -> PersonObservation {
        let width = height * 0.4
        let face = CGRect(x: eyes.x - width * 0.25, y: eyes.y - height * 0.06, width: width * 0.5, height: height * 0.14)
        let body = CGRect(x: eyes.x - width / 2, y: eyes.y - height * 0.1, width: width, height: height)
        return PersonObservation(bodyRect: body, faceRect: face, eyeCenter: eyes, facing: facing)
    }

    func run(_ engine: CompositionEngine, _ obs: SceneObservation, mode: CompositionMode = .auto,
             frames: Int = 12, start: TimeInterval = 0) -> GuideFrame {
        var frame = GuideFrame.empty
        for i in 0..<frames {
            frame = engine.process(obs, mode: mode, time: start + Double(i) / 10)
        }
        return frame
    }

    // MARK: Portrait

    func testCenteredPersonFacingRightIsGuidedLeftForLookingRoom() {
        let engine = CompositionEngine()
        let obs = SceneObservation(people: [person(eyesAt: CGPoint(x: 0.5, y: 0.33), facing: 0.6)])
        let frame = run(engine, obs)
        let result = try! XCTUnwrap(frame.result)
        XCTAssertEqual(result.scene, .portrait)
        XCTAssertFalse(result.isOptimal)
        XCTAssertLessThan(result.targetCenter.x, result.subjectCenter.x, "subject should move left to leave room on the right")
        guard case .moveSubject(let dir, _) = frame.tip else { return XCTFail("expected a move tip, got \(frame.tip)") }
        XCTAssertTrue([.left, .upLeft, .downLeft].contains(dir))
    }

    func testPersonOnThirdsWithGoodHeadroomIsOptimal() {
        let engine = CompositionEngine()
        let obs = SceneObservation(people: [person(eyesAt: CGPoint(x: 1.0 / 3.0, y: 1.0 / 3.0), facing: 0.6)])
        let frame = run(engine, obs)
        XCTAssertEqual(frame.result?.isOptimal, true)
        XCTAssertEqual(frame.tip, .goodComposition)
    }

    func testFrontalCenteredPortraitIsAcceptable() {
        let engine = CompositionEngine()
        let obs = SceneObservation(people: [person(eyesAt: CGPoint(x: 0.5, y: 1.0 / 3.0), facing: 0)])
        let frame = run(engine, obs)
        XCTAssertEqual(frame.result?.isOptimal, true, "center composition must not always be penalized")
    }

    func testTinyPersonAsksToMoveCloser() {
        let engine = CompositionEngine()
        let obs = SceneObservation(people: [person(eyesAt: CGPoint(x: 0.5, y: 0.5), height: 0.18)])
        XCTAssertEqual(run(engine, obs).tip, .moveCloser)
    }

    func testPortraitModeWithoutPeopleAsksToFindPerson() {
        let engine = CompositionEngine()
        let obs = SceneObservation(salientObjects: [SalientObject(rect: CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2), confidence: 1)])
        let frame = run(engine, obs, mode: .portrait)
        XCTAssertNil(frame.result)
        XCTAssertEqual(frame.tip, .findPerson)
    }

    // MARK: Group

    func testBalancedGroupIsOptimal() {
        let engine = CompositionEngine()
        let obs = SceneObservation(people: [
            person(eyesAt: CGPoint(x: 0.36, y: 1.0 / 3.0), height: 0.55),
            person(eyesAt: CGPoint(x: 0.64, y: 1.0 / 3.0), height: 0.55)
        ])
        let frame = run(engine, obs)
        XCTAssertEqual(frame.result?.scene, .group)
        XCTAssertEqual(frame.result?.isOptimal, true)
    }

    // MARK: Object

    func testIsolatedSymmetricObjectCanStayCentered() {
        let engine = CompositionEngine()
        let obs = SceneObservation(
            salientObjects: [SalientObject(rect: CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.3), confidence: 0.9)],
            saliency: SaliencySummary(centroid: CGPoint(x: 0.5, y: 0.5), region: CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.3),
                                      horizontalSymmetry: 0.95, bottomMass: 0.2, spread: 0.1))
        let frame = run(engine, obs)
        XCTAssertEqual(frame.result?.scene, .object)
        XCTAssertEqual(frame.result?.isOptimal, true)
    }

    func testOffBalanceObjectGetsThirdsTarget() {
        let engine = CompositionEngine()
        let obs = SceneObservation(
            salientObjects: [SalientObject(rect: CGRect(x: 0.03, y: 0.62, width: 0.2, height: 0.2), confidence: 0.9)],
            saliency: SaliencySummary(centroid: CGPoint(x: 0.13, y: 0.72), region: CGRect(x: 0.03, y: 0.62, width: 0.2, height: 0.2),
                                      horizontalSymmetry: 0.2, bottomMass: 0.5, spread: 0.1))
        let result = try! XCTUnwrap(run(engine, obs).result)
        XCTAssertFalse(result.isOptimal)
        XCTAssertGreaterThan(result.targetCenter.x, result.subjectCenter.x)
    }

    func testTinyObjectAsksToMoveCloser() {
        let engine = CompositionEngine()
        let obs = SceneObservation(salientObjects: [SalientObject(rect: CGRect(x: 0.45, y: 0.45, width: 0.08, height: 0.08), confidence: 1)])
        XCTAssertEqual(run(engine, obs, mode: .object).tip, .moveCloser)
    }

    // MARK: Landscape

    func testTiltedLandscapeAsksToLevel() {
        let engine = CompositionEngine()
        let obs = SceneObservation(
            saliency: SaliencySummary(centroid: CGPoint(x: 1.0 / 3.0, y: 2.0 / 3.0), region: CGRect(x: 0.2, y: 0.55, width: 0.25, height: 0.2),
                                      horizontalSymmetry: 0.3, bottomMass: 0.4, spread: 0.2),
            deviceRoll: 8 * .pi / 180)
        XCTAssertEqual(run(engine, obs, mode: .landscape).tip, .levelHorizon)
    }

    func testLandscapeTipPansCameraOppositeToBoxMotion() {
        let engine = CompositionEngine()
        let obs = SceneObservation(
            saliency: SaliencySummary(centroid: CGPoint(x: 0.9, y: 0.5), region: CGRect(x: 0.8, y: 0.4, width: 0.15, height: 0.2),
                                      horizontalSymmetry: 0.1, bottomMass: 0.3, spread: 0.2),
            deviceRoll: 0)
        let frame = run(engine, obs, mode: .landscape)
        let result = try! XCTUnwrap(frame.result)
        XCTAssertLessThan(result.targetCenter.x, result.subjectCenter.x)
        guard case .panCamera(let dir, _) = frame.tip else { return XCTFail("expected pan tip, got \(frame.tip)") }
        XCTAssertTrue([.right, .upRight, .downRight].contains(dir), "content must move left → pan camera right")
    }

    // MARK: Stability

    func testJitterDoesNotMoveTargetOrFlickerTip() {
        let engine = CompositionEngine()
        var anchors = Set<AnchorID>()
        var tips: [GuideTip] = []
        for i in 0..<60 {
            let jitter = CGFloat((i * 7919) % 11 - 5) / 500 // ±0.01
            let obs = SceneObservation(people: [person(eyesAt: CGPoint(x: 0.5 + jitter, y: 0.45 - jitter), facing: 0.6)])
            let frame = engine.process(obs, mode: .auto, time: Double(i) / 12)
            if i > 5, let r = frame.result { anchors.insert(r.anchor) }
            tips.append(frame.tip)
        }
        XCTAssertEqual(anchors.count, 1, "target anchor must stay locked under jitter")
        let changes = zip(tips, tips.dropFirst()).filter { $0 != $1 }.count
        XCTAssertLessThanOrEqual(changes, 2)
    }

    func testReachingTargetBecomesOptimalOnceWithHysteresis() {
        let engine = CompositionEngine()
        var optimalEvents = 0
        var last: GuideFrame = .empty
        // Walk the subject from the center to the left third, then jitter around it.
        for i in 0..<80 {
            let t = min(CGFloat(i) / 40, 1)
            let x = 0.5 - (0.5 - 1.0 / 3.0) * t + (i > 40 ? CGFloat(i % 3 - 1) * 0.006 : 0)
            let obs = SceneObservation(people: [person(eyesAt: CGPoint(x: x, y: 1.0 / 3.0), facing: 0.6)])
            last = engine.process(obs, mode: .auto, time: Double(i) / 12)
            if last.didBecomeOptimal { optimalEvents += 1 }
        }
        XCTAssertEqual(optimalEvents, 1, "haptic trigger must fire exactly once")
        XCTAssertEqual(last.result?.isOptimal, true)
        XCTAssertEqual(last.tip, .goodComposition)
    }

    func testBriefDropoutHoldsGuide() {
        let engine = CompositionEngine()
        let obs = SceneObservation(people: [person(eyesAt: CGPoint(x: 0.5, y: 0.33), facing: 0.6)])
        _ = run(engine, obs, frames: 10)
        let dropped = engine.process(SceneObservation(), mode: .auto, time: 1.05)
        XCTAssertNotNil(dropped.result, "a single missed detection must not hide the guide")
        let gone = engine.process(SceneObservation(), mode: .auto, time: 3)
        XCTAssertNil(gone.result)
    }
}

final class GeometryTests: XCTestCase {
    func testClampKeepsRectInsideFrame() {
        let r = CGRect(x: 0.9, y: -0.1, width: 0.3, height: 0.3).clampedInside()
        XCTAssertEqual(r.maxX, 1, accuracy: 1e-9)
        XCTAssertEqual(r.minY, 0, accuracy: 1e-9)
    }

    func testVisionFlip() {
        let r = CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.3).flippedVertically
        XCTAssertEqual(r.minY, 0.6, accuracy: 1e-9)
    }

    func testDirectionClassification() {
        XCTAssertEqual(GuideDirection.from(CGVector(dx: 0.2, dy: 0.01)), .right)
        XCTAssertEqual(GuideDirection.from(CGVector(dx: -0.1, dy: -0.1)), .upLeft)
        XCTAssertEqual(GuideDirection.from(CGVector(dx: 0, dy: 0.3)), .down)
        XCTAssertEqual(GuideDirection.from(CGVector(dx: 0.0001, dy: 0)), .none)
    }

    func testPersonAssemblerPairsFaceWithBody() {
        let people = PersonAssembler.assemble(
            bodies: [BodyInput(rect: CGRect(x: 0.4, y: 0.2, width: 0.2, height: 0.6))],
            faces: [FaceInput(rect: CGRect(x: 0.45, y: 0.22, width: 0.1, height: 0.08)),
                    FaceInput(rect: CGRect(x: 0.05, y: 0.1, width: 0.06, height: 0.05))])
        XCTAssertEqual(people.count, 2)
        XCTAssertNotNil(people[0].faceRect)
        XCTAssertNil(people[1].bodyRect)
    }
}

final class FrameQuadrantTests: XCTestCase {
    func testRoundTrip() {
        let r = CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        for q in [FrameQuadrant.portrait, .gravityRight, .gravityLeft] {
            let back = q.toPhoto(q.toScreen(r))
            XCTAssertEqual(back.minX, r.minX, accuracy: 1e-9)
            XCTAssertEqual(back.minY, r.minY, accuracy: 1e-9)
            XCTAssertEqual(back.width, r.width, accuracy: 1e-9)
        }
    }

    func testGravityRightPhotoTopIsScreenLeft() {
        // The top-center of the photo must be drawn at the left-center of the screen.
        let p = FrameQuadrant.gravityRight.toScreen(CGPoint(x: 0.5, y: 0))
        XCTAssertEqual(p.x, 0, accuracy: 1e-9)
        XCTAssertEqual(p.y, 0.5, accuracy: 1e-9)
    }

    func testHysteresis() {
        XCTAssertEqual(FrameQuadrant.from(angle: 50 * .pi / 180, current: .portrait), .portrait)
        XCTAssertEqual(FrameQuadrant.from(angle: 60 * .pi / 180, current: .portrait), .gravityRight)
        XCTAssertEqual(FrameQuadrant.from(angle: 40 * .pi / 180, current: .gravityRight), .gravityRight)
        XCTAssertEqual(FrameQuadrant.from(angle: -80 * .pi / 180, current: .portrait), .gravityLeft)
    }
}

final class SelectionAndStyleTests: XCTestCase {
    func person(x: CGFloat, height: CGFloat = 0.5) -> PersonObservation {
        let eyes = CGPoint(x: x, y: 0.35)
        return PersonObservation(bodyRect: CGRect(x: x - 0.1, y: 0.3, width: 0.2, height: height),
                                 faceRect: CGRect(x: x - 0.05, y: 0.31, width: 0.1, height: 0.07), eyeCenter: eyes, facing: 0)
    }

    let cup = SalientObject(rect: CGRect(x: 0.62, y: 0.62, width: 0.2, height: 0.2), confidence: 0.9)

    func testTrackerKeepsIDsWhileSubjectsMove() {
        let tracker = SubjectTracker()
        let first = tracker.update(SceneObservation(people: [person(x: 0.3)], salientObjects: [cup]), time: 0)
        XCTAssertEqual(Set(first.map(\.kind)), [.person, .object])
        var ids = Set(first.map(\.id))
        for i in 1...20 {
            let moved = tracker.update(SceneObservation(people: [person(x: 0.3 + CGFloat(i) * 0.01)], salientObjects: [cup]),
                                       time: Double(i) / 10)
            ids.formUnion(moved.map(\.id))
        }
        XCTAssertEqual(ids.count, 2, "IDs must stay stable while subjects move smoothly")
    }

    func testObjectnessBoxOnAPersonIsNotAnExtraCandidate() {
        let tracker = SubjectTracker()
        let p = person(x: 0.5)
        let onPerson = SalientObject(rect: p.bodyRect!.insetBy(dx: 0.01, dy: 0.01), confidence: 1)
        let visible = tracker.update(SceneObservation(people: [p], salientObjects: [onPerson]), time: 0)
        XCTAssertEqual(visible.map(\.kind), [.person])
    }

    func testManualSelectionOverridesAutomaticSubject() {
        let engine = CompositionEngine()
        let obs = SceneObservation(people: [person(x: 0.3)], salientObjects: [cup])
        let auto = engine.process(obs, mode: .auto, time: 0)
        XCTAssertEqual(auto.result?.subjectKind, .person)
        let cupID = try! XCTUnwrap(auto.subjects.first { $0.kind == .object }?.id)

        var frame = auto
        for i in 1...8 { frame = engine.process(obs, mode: .auto, selection: .manual(cupID), time: Double(i) / 10) }
        XCTAssertEqual(frame.result?.subjectKind, .object)
        XCTAssertEqual(frame.result?.subjectID, cupID)
        XCTAssertEqual(frame.selectedID, cupID)
        XCTAssertEqual(frame.recommendedStyle, .vivid)
    }

    func testLostSelectionFallsBackToAutomatic() {
        let engine = CompositionEngine()
        let obs = SceneObservation(people: [person(x: 0.3)], salientObjects: [cup])
        let cupID = engine.process(obs, mode: .auto, time: 0).subjects.first { $0.kind == .object }!.id
        _ = engine.process(obs, mode: .auto, selection: .manual(cupID), time: 0.1)
        let noCup = SceneObservation(people: [person(x: 0.3)])
        var lost = false
        var frame = GuideFrame.empty
        for i in 2...30 {
            frame = engine.process(noCup, mode: .auto, selection: lost ? .automatic : .manual(cupID), time: Double(i) / 10)
            if frame.selectionLost { lost = true }
        }
        XCTAssertTrue(lost)
        XCTAssertEqual(frame.result?.subjectKind, .person)
    }

    func testPetBeatsGenericObjectInAuto() {
        let engine = CompositionEngine()
        let dog = AnimalObservation(rect: CGRect(x: 0.2, y: 0.4, width: 0.3, height: 0.3), label: "Dog", confidence: 0.9)
        var frame = GuideFrame.empty
        for i in 0..<6 { frame = engine.process(SceneObservation(salientObjects: [cup], animals: [dog]), mode: .auto, time: Double(i) / 10) }
        XCTAssertEqual(frame.result?.subjectKind, .pet)
        XCTAssertEqual(Set(frame.subjects.map(\.kind)), [.pet, .object])
    }

    func testStyleMappingAndHints() {
        XCTAssertEqual(StyleRecommender.style(for: .person, hints: SceneHints()), .warm)
        XCTAssertEqual(StyleRecommender.style(for: .group, hints: SceneHints()), .bright)
        XCTAssertEqual(StyleRecommender.style(for: .object, hints: SceneHints.from(labels: [("baked_goods", 0.6)])), .food)
        XCTAssertEqual(StyleRecommender.style(for: .scene, hints: SceneHints.from(labels: [("sunset_sunrise", 0.7)])), .golden)
        XCTAssertEqual(StyleRecommender.style(for: .scene, hints: SceneHints.from(labels: [("mountain", 0.1)])), .landscape)
        XCTAssertFalse(SceneHints.from(labels: [("food", 0.1)]).isFood, "weak labels are ignored")
    }

    func testStyleHysteresis() {
        var r = StyleRecommender()
        XCTAssertEqual(r.update(kind: .person, hints: SceneHints(), time: 0), .warm)
        XCTAssertEqual(r.update(kind: .object, hints: SceneHints(), time: 0.3), .warm)
        XCTAssertEqual(r.update(kind: .person, hints: SceneHints(), time: 0.5), .warm)
        XCTAssertEqual(r.update(kind: .object, hints: SceneHints(), time: 0.6), .warm)
        XCTAssertEqual(r.update(kind: .object, hints: SceneHints(), time: 1.7), .vivid)
    }

    func testStyleParametersInterpolate() {
        let mid = StyleParameters.lerp(.natural, PhotoStyle.mono.parameters, 0.5)
        XCTAssertEqual(mid.saturation, 0.5, accuracy: 1e-9)
        XCTAssertTrue(StyleParameters.natural.isIdentity)
        XCTAssertFalse(PhotoStyle.warm.parameters.isIdentity)
        XCTAssertEqual(StyleParameters.lerp(.natural, PhotoStyle.vivid.parameters, 1), PhotoStyle.vivid.parameters)
    }

    func testFocusPointIsEyeLineForPeople() {
        let engine = CompositionEngine()
        let frame = engine.process(SceneObservation(people: [person(x: 0.4)]), mode: .auto, time: 0)
        XCTAssertEqual(frame.result?.focusPoint?.y ?? 0, 0.35, accuracy: 1e-6)
    }
}
