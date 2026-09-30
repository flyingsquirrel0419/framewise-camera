import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// The subject the guide is built around, resolved for one scene type.
public struct ResolvedSubject: Equatable, Sendable {
    public var scene: SceneType
    public var kind: SubjectKind
    public var rect: CGRect
    /// The point placed onto candidate anchors (eye line, object center, ...).
    public var keyPoint: CGPoint
    /// Top of the head(s), for headroom. Only for people.
    public var headTop: CGFloat?
    public var facing: CGFloat?
    /// Area-weighted centroid of other salient content, for visual balance.
    public var secondaryMass: (point: CGPoint, weight: CGFloat)?
    /// Number of people in a group.
    public var memberCount: Int
    public var faceHeight: CGFloat?

    public static func == (lhs: ResolvedSubject, rhs: ResolvedSubject) -> Bool {
        lhs.scene == rhs.scene && lhs.kind == rhs.kind && lhs.rect == rhs.rect
            && lhs.keyPoint == rhs.keyPoint && lhs.headTop == rhs.headTop && lhs.facing == rhs.facing
            && lhs.memberCount == rhs.memberCount && lhs.faceHeight == rhs.faceHeight
            && lhs.secondaryMass?.point == rhs.secondaryMass?.point
            && lhs.secondaryMass?.weight == rhs.secondaryMass?.weight
    }
}

public enum SubjectResolution: Equatable, Sendable {
    case subject(ResolvedSubject)
    /// Nothing usable was found; the tip tells the user what the mode needs.
    case missing(GuideTip)
}

/// Picks the scene type for AUTO mode from raw observations.
public enum SceneClassifier {
    public static func classify(_ obs: SceneObservation) -> SceneType {
        let people = obs.people.filter { ($0.boundingRect?.area ?? 0) > 0.004 }
        if people.count >= 2 { return .group }
        if people.count == 1 { return .portrait }
        if obs.animals.contains(where: { $0.rect.area > 0.004 }) { return .object }
        if let object = SubjectResolver.primaryObject(in: obs, previous: nil),
           object.rect.area > 0.006, object.rect.area < 0.7 {
            return .object
        }
        return .landscape
    }

    public static func scene(for mode: CompositionMode, observation: SceneObservation) -> SceneType {
        switch mode {
        case .auto: return classify(observation)
        case .portrait:
            return observation.people.count >= 2 ? .group : .portrait
        case .object: return .object
        case .landscape: return .landscape
        }
    }
}

public enum SubjectResolver {
    public static func resolve(scene: SceneType, observation obs: SceneObservation,
                               previous: CGRect?) -> SubjectResolution {
        switch scene {
        case .portrait: return resolvePortrait(obs, previous: previous)
        case .group: return resolveGroup(obs, previous: previous)
        case .object: return resolveObject(obs, previous: previous)
        case .landscape: return resolveLandscape(obs)
        }
    }

    // MARK: People

    static func resolvePortrait(_ obs: SceneObservation, previous: CGRect?) -> SubjectResolution {
        let candidates = obs.people.compactMap { p -> (PersonObservation, CGRect)? in
            guard let r = p.boundingRect else { return nil }
            return (p, r.intersection(NormalizedSpace.frame))
        }.filter { !$0.1.isNull && $0.1.area > 0 }
        guard !candidates.isEmpty else { return .missing(.findPerson) }

        // Largest person wins, but stay on the previously tracked person unless
        // someone is clearly bigger. This keeps the box from hopping between people.
        let largest = candidates.max { $0.1.area < $1.1.area }!
        var chosen = largest
        if let prev = previous,
           let tracked = candidates.max(by: { $0.1.iou(prev) < $1.1.iou(prev) }),
           tracked.1.iou(prev) > 0.2, tracked.1.area > largest.1.area * 0.65 {
            chosen = tracked
        }
        let (person, rect) = chosen
        let key = person.keyPoint ?? rect.center
        let headTop = person.faceRect.map { $0.minY - $0.height * 0.28 } ?? rect.minY
        return .subject(ResolvedSubject(scene: .portrait, kind: .person, rect: rect, keyPoint: key,
                                        headTop: headTop, facing: person.facing, secondaryMass: nil,
                                        memberCount: 1, faceHeight: person.faceRect?.height))
    }

    static func resolveGroup(_ obs: SceneObservation, previous: CGRect?) -> SubjectResolution {
        let people = obs.people.filter { ($0.boundingRect?.area ?? 0) > 0.004 }
        guard people.count >= 2 else { return resolvePortrait(obs, previous: previous) }
        // Ignore tiny background people so they don't stretch the group box.
        let maxArea = people.compactMap { $0.boundingRect?.area }.max() ?? 0
        let members = people.filter { ($0.boundingRect?.area ?? 0) >= maxArea * 0.18 }
        guard members.count >= 2 else { return resolvePortrait(obs, previous: previous) }

        let rects = members.compactMap(\.boundingRect)
        guard let union = CGRect.union(of: rects)?.intersection(NormalizedSpace.frame), !union.isNull else {
            return .missing(.findPerson)
        }
        let keys = members.compactMap(\.keyPoint)
        let eyeY = keys.isEmpty ? union.minY + union.height * 0.15 : keys.map(\.y).reduce(0, +) / CGFloat(keys.count)
        let key = CGPoint(x: union.midX, y: eyeY)
        let headTop = members.map { p -> CGFloat in
            if let f = p.faceRect { return f.minY - f.height * 0.28 }
            return p.boundingRect?.minY ?? union.minY
        }.min()
        let faceHeights = members.compactMap { $0.faceRect?.height }
        let faceHeight = faceHeights.isEmpty ? nil : faceHeights.reduce(0, +) / CGFloat(faceHeights.count)
        return .subject(ResolvedSubject(scene: .group, kind: .group, rect: union, keyPoint: key,
                                        headTop: headTop, facing: nil, secondaryMass: nil,
                                        memberCount: members.count, faceHeight: faceHeight))
    }

    // MARK: Objects

    static func primaryObject(in obs: SceneObservation, previous: CGRect?) -> SalientObject? {
        let objects = obs.salientObjects.filter { $0.rect.area > 0.003 && $0.rect.area < 0.92 }
        guard !objects.isEmpty else { return nil }
        func weight(_ o: SalientObject) -> CGFloat {
            // Prefer confident, reasonably sized, not edge-hugging objects.
            let centerBias = 1 - min(o.rect.center.distance(to: CGPoint(x: 0.5, y: 0.5)), 0.7) * 0.5
            var w = CGFloat(o.confidence) * sqrt(o.rect.area) * centerBias
            if let prev = previous { w *= 1 + o.rect.iou(prev) * 1.5 }
            return w
        }
        return objects.max { weight($0) < weight($1) }
    }

    static func resolveObject(_ obs: SceneObservation, previous: CGRect?) -> SubjectResolution {
        // Pets are the most likely intended subject among "things".
        let pets = obs.animals.filter { $0.rect.area > 0.004 }
        if let pet = pets.max(by: { a, b in
            let wa = a.rect.area * (1 + (previous.map { a.rect.iou($0) } ?? 0))
            let wb = b.rect.area * (1 + (previous.map { b.rect.iou($0) } ?? 0))
            return wa < wb
        }) {
            return .subject(object(rect: pet.rect, kind: .pet, others: obs.salientObjects.map(\.rect)))
        }
        if let object = primaryObject(in: obs, previous: previous) {
            let others = obs.salientObjects.filter { $0.rect != object.rect && $0.rect.iou(object.rect) < 0.3 }
            return .subject(ResolvedSubject(scene: .object, kind: .object, rect: object.rect,
                                            keyPoint: object.rect.center, headTop: nil, facing: nil,
                                            secondaryMass: massCentroid(of: others.map(\.rect)),
                                            memberCount: 1, faceHeight: nil))
        }
        // Fall back to the attention region when objectness found nothing.
        if let s = obs.saliency, s.region.area > 0.01, s.region.area < 0.7 {
            return .subject(ResolvedSubject(scene: .object, kind: .object, rect: s.region,
                                            keyPoint: s.region.center, headTop: nil, facing: nil,
                                            secondaryMass: nil, memberCount: 1, faceHeight: nil))
        }
        return .missing(.findObject)
    }

    /// Resolves a subject the user picked by tapping.
    public static func resolve(tracked t: TrackedSubject, observation obs: SceneObservation) -> ResolvedSubject {
        switch t.kind {
        case .person, .group:
            var person = t.person ?? PersonObservation(bodyRect: t.rect)
            if person.bodyRect == nil && person.faceRect == nil { person.bodyRect = t.rect }
            let single = SceneObservation(people: [person], deviceRoll: obs.deviceRoll, frameAspect: obs.frameAspect)
            if case .subject(let s) = resolvePortrait(single, previous: nil) { return s }
            return object(rect: t.rect, kind: .person, others: [])
        case .pet, .object, .scene:
            let others = obs.salientObjects.map(\.rect) + obs.people.compactMap(\.boundingRect)
            return object(rect: t.rect, kind: t.kind == .scene ? .object : t.kind, others: others)
        }
    }

    static func object(rect: CGRect, kind: SubjectKind, others: [CGRect]) -> ResolvedSubject {
        let rest = others.filter { $0.iou(rect) < 0.3 && rect.intersection($0).area < $0.area * 0.6 }
        return ResolvedSubject(scene: kind == .person ? .portrait : .object, kind: kind, rect: rect,
                               keyPoint: rect.center, headTop: nil, facing: nil,
                               secondaryMass: massCentroid(of: rest), memberCount: 1, faceHeight: nil)
    }

    // MARK: Landscape

    static func resolveLandscape(_ obs: SceneObservation) -> SubjectResolution {
        guard let s = obs.saliency else { return .missing(.searching) }
        var region = s.region.intersection(NormalizedSpace.frame)
        if region.isNull || region.area < 0.002 {
            region = CGRect(x: s.centroid.x - 0.1, y: s.centroid.y - 0.1, width: 0.2, height: 0.2)
        }
        return .subject(ResolvedSubject(scene: .landscape, kind: .scene, rect: region,
                                        keyPoint: s.centroid, headTop: nil, facing: nil,
                                        secondaryMass: nil, memberCount: 0, faceHeight: nil))
    }

    static func massCentroid(of rects: [CGRect]) -> (point: CGPoint, weight: CGFloat)? {
        let total = rects.reduce(0) { $0 + $1.area }
        guard total > 0.002 else { return nil }
        let x = rects.reduce(0) { $0 + $1.midX * $1.area } / total
        let y = rects.reduce(0) { $0 + $1.midY * $1.area } / total
        return (CGPoint(x: x, y: y), total)
    }
}
