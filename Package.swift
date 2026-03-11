// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VTKKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v2),
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
