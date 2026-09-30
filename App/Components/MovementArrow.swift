import SwiftUI

/// A dotted line with a small chevron from the subject box toward the target box.
/// It shortens naturally as the boxes converge and breathes with a slow pulse.
struct MovementArrow: View {
    let from: CGRect
    let to: CGRect
    @State private var pulse = false

    var body: some View {
        let ends = Self.endpoints(from: from, to: to)
        let start = ends.0, end = ends.1
        let length = hypot(end.x - start.x, end.y - start.y)
        ArrowShape(start: start, end: end)
            .stroke(Theme.amber.opacity(pulse ? 0.85 : 0.5),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round, dash: [0.1, 6]))
            .overlay {
                ArrowHead(start: start, end: end)
                    .stroke(Theme.amber.opacity(pulse ? 0.9 : 0.6),
                            style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            }
            .opacity(length > 18 ? 1 : 0)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { pulse = true }
            }
    }

    /// Starts just outside the subject box and stops just short of the target box,
    /// along the line between their centers.
    static func endpoints(from a: CGRect, to b: CGRect) -> (CGPoint, CGPoint) {
        let ca = CGPoint(x: a.midX, y: a.midY), cb = CGPoint(x: b.midX, y: b.midY)
        let dx = cb.x - ca.x, dy = cb.y - ca.y
        let len = max(hypot(dx, dy), 0.001)
        let ux = dx / len, uy = dy / len
        func exit(_ r: CGRect) -> CGFloat {
            // Distance from center to the rect edge along (ux, uy).
            let tx = abs(ux) > 0.0001 ? (r.width / 2) / abs(ux) : .greatestFiniteMagnitude
            let ty = abs(uy) > 0.0001 ? (r.height / 2) / abs(uy) : .greatestFiniteMagnitude
            return min(tx, ty)
        }
        let gap: CGFloat = 8
        var s = exit(a) + gap
        var e = len - exit(b) - gap
        if e - s < 20 {
            // Boxes overlap: draw a short arrow between centers instead.
            s = len * 0.25
            e = len * 0.75
        }
        return (CGPoint(x: ca.x + ux * s, y: ca.y + uy * s), CGPoint(x: ca.x + ux * e, y: ca.y + uy * e))
    }
}

struct ArrowShape: Shape {
    var start: CGPoint
    var end: CGPoint

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(start.x, start.y), AnimatablePair(end.x, end.y)) }
        set {
            start = CGPoint(x: newValue.first.first, y: newValue.first.second)
            end = CGPoint(x: newValue.second.first, y: newValue.second.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: start)
        p.addLine(to: end)
        return p
    }
}

struct ArrowHead: Shape {
    var start: CGPoint
    var end: CGPoint

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(start.x, start.y), AnimatablePair(end.x, end.y)) }
        set {
            start = CGPoint(x: newValue.first.first, y: newValue.first.second)
            end = CGPoint(x: newValue.second.first, y: newValue.second.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let size: CGFloat = 6
        var p = Path()
        p.move(to: CGPoint(x: end.x - size * cos(angle - .pi / 5), y: end.y - size * sin(angle - .pi / 5)))
        p.addLine(to: end)
        p.addLine(to: CGPoint(x: end.x - size * cos(angle + .pi / 5), y: end.y - size * sin(angle + .pi / 5)))
        return p
    }
}
