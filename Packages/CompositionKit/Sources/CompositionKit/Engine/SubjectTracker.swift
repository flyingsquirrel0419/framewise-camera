import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Assigns stable IDs to people, pets and objects across frames by greedy
/// IoU / center-distance matching within each kind. Tracks survive short
/// dropouts so a tapped subject isn't lost when detection flickers.
public final class SubjectTracker {
    private struct Track {
        var subject: TrackedSubject
        var lastSeen: TimeInterval
        var hits: Int
    }

    public var maxMissing: TimeInterval = 1.0
    private var tracks: [Track] = []
    private var nextID = 1

    public init() {}

    public func reset() {
        tracks = []
    }

    /// Updates tracks and returns the subjects visible in this frame.
    @discardableResult
    public func update(_ obs: SceneObservation, time: TimeInterval) -> [TrackedSubject] {
        var detections: [TrackedSubject] = []
        for p in obs.people {
            guard let r = p.boundingRect?.intersection(NormalizedSpace.frame), !r.isNull, r.area > 0.002 else { continue }
            detections.append(TrackedSubject(id: 0, kind: .person, rect: r, confidence: p.confidence, person: p))
        }
        for a in obs.animals where a.rect.area > 0.002 {
            detections.append(TrackedSubject(id: 0, kind: .pet, rect: a.rect, confidence: a.confidence))
        }
        let occupied = detections.map(\.rect)
        for o in obs.salientObjects where o.rect.area > 0.004 && o.rect.area < 0.85 {
            // Objectness also fires on people and pets; keep only distinct things.
            let duplicate = occupied.contains { r in
                let inter = r.intersection(o.rect)
                return !inter.isNull && (inter.area / o.rect.area > 0.5 || r.iou(o.rect) > 0.35)
            }
            if !duplicate { detections.append(TrackedSubject(id: 0, kind: .object, rect: o.rect, confidence: o.confidence)) }
        }

        var matched = Set<Int>()
        var visible: [TrackedSubject] = []
        for var det in detections.sorted(by: { $0.rect.area > $1.rect.area }) {
            var best: (index: Int, score: CGFloat)?
            for (i, t) in tracks.enumerated() where !matched.contains(i) && t.subject.kind == det.kind {
                let iou = t.subject.rect.iou(det.rect)
                let near = t.subject.rect.center.distance(to: det.rect.center)
                let score = iou > 0.15 ? iou : (near < 0.08 ? 0.15 - near : 0)
                if score > 0, score > (best?.score ?? 0) { best = (i, score) }
            }
            if let b = best {
                matched.insert(b.index)
                let old = tracks[b.index].subject.rect
                det.id = tracks[b.index].subject.id
                det.rect = Self.blend(old, det.rect, 0.6)
                tracks[b.index].subject = det
                tracks[b.index].lastSeen = time
                tracks[b.index].hits += 1
            } else {
                det.id = nextID
                nextID += 1
                tracks.append(Track(subject: det, lastSeen: time, hits: 1))
                matched.insert(tracks.count - 1)
            }
            visible.append(det)
        }
        tracks.removeAll { time - $0.lastSeen > maxMissing }
        return visible.sorted { $0.id < $1.id }
    }

    /// The most recent state of a track, if it hasn't been gone longer than `maxMissing`.
    public func subject(id: Int) -> TrackedSubject? {
        tracks.first { $0.subject.id == id }?.subject
    }

    /// Returns the tracked subject that best matches a rect (for highlighting).
    public func bestMatch(for rect: CGRect, in subjects: [TrackedSubject]) -> TrackedSubject? {
        subjects.max { $0.rect.iou(rect) < $1.rect.iou(rect) }.flatMap { $0.rect.iou(rect) > 0.3 ? $0 : nil }
    }

    private static func blend(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
        CGRect(x: a.minX + (b.minX - a.minX) * t, y: a.minY + (b.minY - a.minY) * t,
               width: a.width + (b.width - a.width) * t, height: a.height + (b.height - a.height) * t)
    }
}
