// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "VTKKit",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
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
