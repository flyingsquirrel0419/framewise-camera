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

/// A recognized animal (cat, dog) from Vision's on-device animal recognizer.
public struct AnimalObservation: Equatable, Sendable {
    public var rect: CGRect
    public var label: String
    public var confidence: Float
    public init(rect: CGRect, label: String, confidence: Float) {
        self.rect = rect
        self.label = label
        self.confidence = confidence
    }
}

/// Coarse scene semantics derived from on-device image classification.
public struct SceneHints: Equatable, Sendable {
    public var isFood = false
    public var isNature = false
    public var isGoldenHour = false
    public var isNight = false

    public init(isFood: Bool = false, isNature: Bool = false, isGoldenHour: Bool = false, isNight: Bool = false) {
        self.isFood = isFood
        self.isNature = isNature
        self.isGoldenHour = isGoldenHour
        self.isNight = isNight
    }

    static let foodTerms = ["food", "dessert", "meal", "dish", "fruit", "vegetable", "baked", "bread", "cake",
                            "pizza", "salad", "sushi", "burger", "sandwich", "pasta", "noodle", "coffee",
                            "drink", "beverage", "cocktail", "wine", "icecream", "ice_cream", "breakfast"]
    static let natureTerms = ["sky", "mountain", "beach", "ocean", "sea", "lake", "river", "landscape",
                              "forest", "field", "waterfall", "desert", "snow", "cloud", "hill", "shore",
                              "coast", "canyon", "valley", "meadow", "outdoor", "nature", "park", "garden"]
    static let goldenTerms = ["sunset", "sunrise", "dusk", "dawn"]
    static let nightTerms = ["night", "fireworks", "starry"]

    /// Builds hints from classifier labels. Matching is by substring so it
    /// tolerates taxonomy details (e.g. "sunset_sunrise", "baked_goods").
    public static func from(labels: [(identifier: String, confidence: Float)], threshold: Float = 0.3) -> SceneHints {
        let strong = labels.filter { $0.confidence >= threshold }.map { $0.identifier.lowercased() }
        func any(_ terms: [String]) -> Bool { strong.contains { id in terms.contains { id.contains($0) } } }
        return SceneHints(isFood: any(foodTerms), isNature: any(natureTerms),
                          isGoldenHour: any(goldenTerms), isNight: any(nightTerms))
    }
}

/// Everything the engine knows about the current frame.
public struct SceneObservation: Equatable, Sendable {
    public var people: [PersonObservation]
    public var salientObjects: [SalientObject]
    public var animals: [AnimalObservation]
    public var hints: SceneHints
    public var saliency: SaliencySummary?
    /// Device roll in radians (0 = level), from the motion sensors.
    public var deviceRoll: Double?
    /// width / height of the analyzed frame.
    public var frameAspect: CGFloat
    public var timestamp: TimeInterval

    public init(people: [PersonObservation] = [], salientObjects: [SalientObject] = [],
                animals: [AnimalObservation] = [], hints: SceneHints = SceneHints(),
                saliency: SaliencySummary? = nil, deviceRoll: Double? = nil,
                frameAspect: CGFloat = 3.0 / 4.0, timestamp: TimeInterval = 0) {
        self.people = people
        self.salientObjects = salientObjects
        self.animals = animals
        self.hints = hints
        self.saliency = saliency
        self.deviceRoll = deviceRoll
        self.frameAspect = frameAspect
        self.timestamp = timestamp
    }
}
