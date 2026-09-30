import CoreImage
import CoreImage.CIFilterBuiltins
import CompositionKit

/// Builds the Core Image graph for a `StyleParameters` value. Filter objects
/// are cached per chain; use one chain per thread. Stages at their neutral
/// value are skipped entirely.
final class StyleFilterChain {
    private let matrix = CIFilter.colorMatrix()
    private let controls = CIFilter.colorControls()
    private let vibrance = CIFilter.vibrance()
    private let tone = CIFilter.highlightShadowAdjust()
    private let sharpen = CIFilter.sharpenLuminance()
    private let vignette = CIFilter.vignetteEffect()

    /// `detailScale` scales resolution-dependent effects (sharpening) so the
    /// full-resolution photo matches the preview.
    func apply(_ p: StyleParameters, to input: CIImage, detailScale: Double = 1) -> CIImage {
        guard !p.isIdentity else { return input }
        var image = input

        if abs(p.warmth) > 0.001 {
            let w = CGFloat(p.warmth)
            matrix.inputImage = image
            matrix.rVector = CIVector(x: 1 + 0.08 * w, y: 0, z: 0, w: 0)
            matrix.gVector = CIVector(x: 0, y: 1 + 0.015 * w, z: 0, w: 0)
            matrix.bVector = CIVector(x: 0, y: 0, z: 1 - 0.1 * w, w: 0)
            matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            matrix.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)
            image = matrix.outputImage ?? image
        }
        if abs(p.saturation - 1) > 0.001 || abs(p.contrast - 1) > 0.001 || abs(p.brightness) > 0.001 {
            controls.inputImage = image
            controls.saturation = Float(p.saturation)
            controls.contrast = Float(p.contrast)
            controls.brightness = Float(p.brightness)
            image = controls.outputImage ?? image
        }
        if abs(p.vibrance) > 0.001 {
            vibrance.inputImage = image
            vibrance.amount = Float(p.vibrance)
            image = vibrance.outputImage ?? image
        }
        if abs(p.shadows) > 0.001 || abs(p.highlights - 1) > 0.001 {
            tone.inputImage = image
            tone.shadowAmount = Float(p.shadows)
            tone.highlightAmount = Float(p.highlights)
            image = tone.outputImage ?? image
        }
        if p.sharpness > 0.001 {
            sharpen.inputImage = image
            sharpen.sharpness = Float(p.sharpness * detailScale)
            image = sharpen.outputImage ?? image
        }
        if p.vignette > 0.001 {
            let e = input.extent
            vignette.inputImage = image
            vignette.center = CGPoint(x: e.midX, y: e.midY)
            vignette.radius = Float(hypot(e.width, e.height) * 0.62)
            vignette.intensity = Float(p.vignette)
            vignette.falloff = 0.6
            image = vignette.outputImage ?? image
        }
        return image.cropped(to: input.extent)
    }
}
