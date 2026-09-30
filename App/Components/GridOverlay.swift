import SwiftUI

struct GridOverlay: View {
    var body: some View {
        Canvas { context, size in
            var p = Path()
            for i in 1...2 {
                let x = size.width * CGFloat(i) / 3, y = size.height * CGFloat(i) / 3
                p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(p, with: .color(.white.opacity(0.2)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}

/// A minimal horizon level: a short line that rotates with the tilt and turns
/// amber when level.
struct LevelIndicator: View {
    /// Radians from level.
    let deviation: Double
    let rotation: Double

    private var isLevel: Bool { abs(deviation) < 1.0 * .pi / 180 }

    var body: some View {
        let color = isLevel ? Theme.amber.opacity(0.9) : Color.white.opacity(0.55)
        HStack(spacing: 0) {
            Capsule().fill(color).frame(width: 22, height: 1)
            Spacer().frame(width: 34)
            Capsule().fill(color).frame(width: 22, height: 1)
        }
        .rotationEffect(.radians(isLevel ? 0 : -deviation))
        .overlay {
            HStack(spacing: 64) {
                Capsule().fill(Color.white.opacity(0.3)).frame(width: 8, height: 1)
                Capsule().fill(Color.white.opacity(0.3)).frame(width: 8, height: 1)
            }
        }
        .rotationEffect(.degrees(rotation))
        .animation(.smooth(duration: 0.2), value: deviation)
        .animation(.smooth(duration: 0.3), value: isLevel)
        .opacity(abs(deviation) < 25 * .pi / 180 ? 1 : 0)
        .allowsHitTesting(false)
    }
}
