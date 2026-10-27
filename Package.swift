// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "VTKKit",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(
            name: "VTKKit",
            targets: ["VTKKit"]
        ),
    ],
    targets: [
        .target(
            name: "VTKKit"
        ),
        .testTarget(
            name: "VTKKitTests",
            dependencies: ["VTKKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
