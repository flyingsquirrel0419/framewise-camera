import CoreImage
import ImageIO
import UniformTypeIdentifiers
import CompositionKit

/// Applies a style to a captured photo at full resolution, keeping its metadata.
enum PhotoStyler {
    private static let context = CIContext()

    static func apply(_ parameters: StyleParameters, to data: Data, preferHEIF: Bool) -> Data {
        guard !parameters.isIdentity,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let input = CIImage(data: data, options: [.applyOrientationProperty: true]) else { return data }

        // Sharpening is tuned on the ~1440 px preview; scale it for the photo.
        let detail = max(1, Double(max(input.extent.width, input.extent.height)) / 1440)
        let output = StyleFilterChain().apply(parameters, to: input, detailScale: min(detail, 2.5))
        let colorSpace = input.colorSpace ?? CGColorSpace(name: CGColorSpace.displayP3)!
        guard let cgImage = context.createCGImage(output, from: output.extent, format: .RGBA8, colorSpace: colorSpace) else {
            return data
        }

        // Orientation was applied to the pixels, so reset it in the metadata.
        var properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        properties[kCGImagePropertyOrientation] = 1
        if var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = 1
            properties[kCGImagePropertyTIFFDictionary] = tiff
        }
        properties[kCGImageDestinationLossyCompressionQuality] = 0.92

        for type in preferHEIF ? [UTType.heic, .jpeg] : [.jpeg] {
            let out = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil) else { continue }
            CGImageDestinationAddImage(dest, cgImage, properties as CFDictionary)
            if CGImageDestinationFinalize(dest) { return out as Data }
        }
        return data
    }
}
