// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EntityKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        .library(name: "EntityKit", targets: ["EntityKit"])
    ],
    targets: [
        .target(name: "EntityKit"),
        .testTarget(name: "EntityKitTests", dependencies: ["EntityKit"])
    ]
)
