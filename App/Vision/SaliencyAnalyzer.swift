import Vision
import CoreVideo
import CompositionKit

/// Attention-based saliency: where a viewer's eye goes. Summarized into a
/// centroid, main region, left/right symmetry and foreground weight.
final class SaliencyAnalyzer {
    let request = VNGenerateAttentionBasedSaliencyImageRequest()

    func summary() -> SaliencySummary? {
        guard let observation = request.results?.first else { return nil }
        let buffer = observation.pixelBuffer
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_OneComponent32Float else { return nil }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer) / MemoryLayout<Float>.size
        let values = base.assumingMemoryBound(to: Float.self)
        guard width > 1, height > 1 else { return nil }

        var total: Float = 0, sx: Float = 0, sy: Float = 0, bottom: Float = 0, asymmetry: Float = 0
        var maxValue: Float = 0
        for y in 0..<height {
            let row = values + y * stride
            for x in 0..<width {
                let v = max(0, row[x])
                total += v
                sx += v * Float(x)
                sy += v * Float(y)
                if y >= height * 2 / 3 { bottom += v }
                if x < width / 2 { asymmetry += abs(v - max(0, row[width - 1 - x])) }
                maxValue = max(maxValue, v)
            }
        }
        guard total > 0.0001 else { return nil }

        let cx = sx / total / Float(width - 1)
        let cy = sy / total / Float(height - 1)
        var spread: Float = 0
        for y in 0..<height {
            let row = values + y * stride
            for x in 0..<width {
                let dx = Float(x) / Float(width - 1) - cx
                let dy = Float(y) / Float(height - 1) - cy
                spread += max(0, row[x]) * (dx * dx + dy * dy)
            }
        }

        let region: CGRect
        if let box = observation.salientObjects?.max(by: { $0.boundingBox.area < $1.boundingBox.area })?.boundingBox {
            region = box.flippedVertically
        } else {
            region = CGRect(x: CGFloat(cx) - 0.12, y: CGFloat(cy) - 0.12, width: 0.24, height: 0.24)
        }
        return SaliencySummary(
            centroid: CGPoint(x: CGFloat(cx), y: CGFloat(cy)),
            region: region,
            horizontalSymmetry: Double(max(0, 1 - asymmetry / total)),
            bottomMass: Double(bottom / total),
            spread: Double(sqrt(spread / total))
        )
    }
}
