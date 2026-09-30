import AVFoundation
import CoreImage
import CompositionKit
import os

/// Draws camera frames into an `AVSampleBufferDisplayLayer`, applying the active
/// style on the GPU. Frames are already upright (and mirrored for the front
/// camera), so the preview shows exactly the pixels the analysis sees. Style
/// changes cross-fade by interpolating parameters over ~0.4 s.
final class FilteredPreviewRenderer: @unchecked Sendable {
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let chain = StyleFilterChain()
    private let colorSpace = CGColorSpace(name: CGColorSpace.itur_709)!
    private let target = OSAllocatedUnfairLock(initialState: StyleParameters.natural)
    private let layerLock = NSLock()
    private weak var layer: AVSampleBufferDisplayLayer?

    // Video queue only.
    private var current = StyleParameters.natural
    private var pool: CVPixelBufferPool?
    private var poolSize: CGSize = .zero
    private var formatDescription: CMVideoFormatDescription?

    func attach(_ layer: AVSampleBufferDisplayLayer) {
        layerLock.withLock { self.layer = layer }
    }

    func setStyle(_ parameters: StyleParameters) {
        target.withLock { $0 = parameters }
    }

    /// Called on the video queue for every frame.
    func render(_ source: CVPixelBuffer) {
        let goal = target.withLock { $0 }
        if current != goal {
            current = current.distance(to: goal) < 0.004 ? goal : .lerp(current, goal, 0.14)
        }
        guard let layer = layerLock.withLock({ self.layer }) else { return }

        var output = source
        if !current.isIdentity, let buffer = makeBuffer(like: source) {
            let image = chain.apply(current, to: CIImage(cvPixelBuffer: source))
            context.render(image, to: buffer, bounds: image.extent, colorSpace: colorSpace)
            output = buffer
        }
        enqueue(output, on: layer)
    }

    private func makeBuffer(like source: CVPixelBuffer) -> CVPixelBuffer? {
        let size = CGSize(width: CVPixelBufferGetWidth(source), height: CVPixelBufferGetHeight(source))
        if pool == nil || size != poolSize {
            let attrs: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
                kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
            ]
            var newPool: CVPixelBufferPool?
            CVPixelBufferPoolCreate(nil, [kCVPixelBufferPoolMinimumBufferCountKey as String: 3] as CFDictionary,
                                    attrs as CFDictionary, &newPool)
            pool = newPool
            poolSize = size
        }
        guard let pool else { return nil }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        if let buffer {
            CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
            CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
        }
        return buffer
    }

    private func enqueue(_ buffer: CVPixelBuffer, on layer: AVSampleBufferDisplayLayer) {
        if formatDescription == nil || !CMVideoFormatDescriptionMatchesImageBuffer(formatDescription!, imageBuffer: buffer) {
            var desc: CMVideoFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: buffer, formatDescriptionOut: &desc)
            formatDescription = desc
        }
        guard let format = formatDescription else { return }
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
                                        decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: buffer, formatDescription: format,
                                                 sampleTiming: &timing, sampleBufferOut: &sample)
        guard let sample else { return }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true),
           CFArrayGetCount(attachments) > 0 {
            let dict = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dict, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        let renderer = layer.sampleBufferRenderer
        if renderer.status == .failed { renderer.flush() }
        renderer.enqueue(sample)
    }
}
