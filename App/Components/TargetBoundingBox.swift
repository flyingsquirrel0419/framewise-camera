import SwiftUI

/// The recommended position: corner brackets over a faint dashed outline.
/// It grows more visible as the subject approaches.
struct TargetBoundingBox: View {
    let rect: CGRect
    /// 0 = far away, 1 = on target.
    let proximity: Double
    var tint: Color = Theme.amber

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(tint.opacity(0.16 + 0.14 * proximity),
                        style: StrokeStyle(lineWidth: 0.8, dash: [3, 5]))
            CornerBrackets(length: min(16, min(rect.width, rect.height) * 0.3))
                .stroke(tint.opacity(0.45 + 0.35 * proximity),
                        style: StrokeStyle(lineWidth: Theme.guideLine, lineCap: .round, lineJoin: .round))
        }
        .frame(width: max(rect.width, 1), height: max(rect.height, 1))
        .overlay(alignment: .topLeading) {
            BoxLabel(key: "label.target", opacity: 0.5 + 0.2 * proximity, tint: tint)
                .offset(y: -17)
        }
        .position(x: rect.midX, y: rect.midY)
    }
}

/// Four corner-only strokes.
struct CornerBrackets: Shape {
    var length: CGFloat
    var radius: CGFloat = 4

    var animatableData: CGFloat {
        get { length }
        set { length = newValue }
    }

    func path(in r: CGRect) -> Path {
        var p = Path()
        let l = max(4, min(length, r.width / 2, r.height / 2))
        let c = min(radius, l / 2)
        // top-left
        p.move(to: CGPoint(x: r.minX, y: r.minY + l))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        p.addQuadCurve(to: CGPoint(x: r.minX + c, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + l, y: r.minY))
        // top-right
        p.move(to: CGPoint(x: r.maxX - l, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + c), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + l))
        // bottom-right
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - l))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addQuadCurve(to: CGPoint(x: r.maxX - c, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - l, y: r.maxY))
        // bottom-left
        p.move(to: CGPoint(x: r.minX + l, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - c), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - l))
        return p
    }
}
