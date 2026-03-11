// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VTKKit",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1),
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
