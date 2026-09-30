import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// One detected person. All rects are normalized, top-left origin, in the
/// upright (display-oriented) frame.
public struct PersonObservation: Equatable, Sendable {
    public var bodyRect: CGRect?
    public var faceRect: CGRect?
    /// Midpoint between the eyes, if landmarks were available.
    public var eyeCenter: CGPoint?
    /// Horizontal gaze/face direction in image space: negative = facing frame-left,
    /// positive = facing frame-right, roughly in [-1, 1]. `nil` when unknown.
    public var facing: CGFloat?
    public var confidence: Float

    public init(bodyRect: CGRect? = nil, faceRect: CGRect? = nil, eyeCenter: CGPoint? = nil,
                facing: CGFloat? = nil, confidence: Float = 1) {
        self.bodyRect = bodyRect
        self.faceRect = faceRect
        self.eyeCenter = eyeCenter
        self.facing = facing
        self.confidence = confidence
    }

    /// Best available box for the whole person. A lone face is expanded to an
    /// approximate head-and-shoulders box.
    public var boundingRect: CGRect? {
        if let body = bodyRect {
            if let face = faceRect { return body.union(face) }
            return body
        }
        guard let face = faceRect else { return nil }
        let w = face.width * 2.2
        let h = face.height * 2.6
        return CGRect(x: face.midX - w / 2, y: face.minY - face.height * 0.35, width: w, height: h)
    }

    /// The point the eye line should sit on.
    public var keyPoint: CGPoint? {
        if let eyes = eyeCenter { return eyes }
        if let face = faceRect { return CGPoint(x: face.midX, y: face.minY + face.height * 0.42) }
        if let body = bodyRect { return CGPoint(x: body.midX, y: body.minY + body.height * 0.12) }
        return nil
    }
}

/// Condensed statistics from an attention-saliency heat map.
public struct SaliencySummary: Equatable, Sendable {
    /// Mass-weighted centroid of the heat map.
    public var centroid: CGPoint
    /// Box around the high-attention region.
    public var region: CGRect
    /// Left/right mirror similarity in [0, 1]; 1 = perfectly symmetric.
    public var horizontalSymmetry: Double
    /// Fraction of total mass in the bottom third (foreground weight).
    public var bottomMass: Double
    /// Spread of the mass (0 = concentrated, ~0.4 = uniform).
    public var spread: Double

    public init(centroid: CGPoint, region: CGRect, horizontalSymmetry: Double,
                bottomMass: Double, spread: Double) {
        self.centroid = centroid
        self.region = region
        self.horizontalSymmetry = horizontalSymmetry
        self.bottomMass = bottomMass
        self.spread = spread
    }
}

public struct SalientObject: Equatable, Sendable {
    public var rect: CGRect
    public var confidence: Float
    public init(rect: CGRect, confidence: Float) {
        self.rect = rect
        self.confidence = confidence
    }
}

/// Everything the engine knows about the current frame.
public struct SceneObservation: Equatable, Sendable {
    public var people: [PersonObservation]
    public var salientObjects: [SalientObject]
    public var saliency: SaliencySummary?
    /// Device roll in radians (0 = level), from the motion sensors.
    public var deviceRoll: Double?
    /// width / height of the analyzed frame.
    public var frameAspect: CGFloat
    public var timestamp: TimeInterval

    public init(people: [PersonObservation] = [], salientObjects: [SalientObject] = [],
                saliency: SaliencySummary? = nil, deviceRoll: Double? = nil,
                frameAspect: CGFloat = 3.0 / 4.0, timestamp: TimeInterval = 0) {
        self.people = people
        self.salientObjects = salientObjects
        self.saliency = saliency
        self.deviceRoll = deviceRoll
        self.frameAspect = frameAspect
        self.timestamp = timestamp
    }
}
