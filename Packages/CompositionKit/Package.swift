// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CompositionKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CompositionKit", targets: ["CompositionKit"])
    ],
    targets: [
        .target(name: "CompositionKit"),
        .testTarget(name: "CompositionKitTests", dependencies: ["CompositionKit"])
    ]
)
