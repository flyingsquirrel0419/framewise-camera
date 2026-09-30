import Vision
import CompositionKit

/// Faces with landmarks. Landmarks give the eye line (for headroom / thirds) and
/// the facing direction (for looking room) in image space.
final class FaceDetector {
    let request = VNDetectFaceLandmarksRequest()

    func faces() -> [FaceInput] {
        (request.results ?? []).map { face in
            let box = face.boundingBox
            let rect = box.flippedVertically
            var eyeCenter: CGPoint?
            var facing: CGFloat?
            if let landmarks = face.landmarks,
               let left = centroid(landmarks.leftEye?.normalizedPoints),
               let right = centroid(landmarks.rightEye?.normalizedPoints) {
                let l = toImage(left, in: box), r = toImage(right, in: box)
                let mid = CGPoint(x: (l.x + r.x) / 2, y: (l.y + r.y) / 2)
                eyeCenter = mid.flippedVertically
                let interEye = hypot(l.x - r.x, l.y - r.y)
                if interEye > 0.001, let nose = centroid(landmarks.nose?.normalizedPoints) {
                    // The nose shifts toward the side the face is turned to.
                    let n = toImage(nose, in: box)
                    facing = max(-1, min(1, (n.x - mid.x) / interEye * 2))
                }
            }
            return FaceInput(rect: rect, eyeCenter: eyeCenter, facing: facing, confidence: face.confidence)
        }
    }

    private func centroid(_ points: [CGPoint]?) -> CGPoint? {
        guard let points, !points.isEmpty else { return nil }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }

    /// Landmark points are normalized to the face box (bottom-left origin).
    private func toImage(_ p: CGPoint, in box: CGRect) -> CGPoint {
        CGPoint(x: box.minX + p.x * box.width, y: box.minY + p.y * box.height)
    }
}
