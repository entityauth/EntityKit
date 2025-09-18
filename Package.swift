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
    dependencies: [
        .package(url: "https://github.com/entityauth/convex-swift.git", branch: "main")
    ],
    targets: [
        .target(
            name: "EntityKit",
            dependencies: [
                .product(name: "ConvexMobile", package: "convex-swift")
            ]
        ),
        .testTarget(name: "EntityKitTests", dependencies: ["EntityKit"])
    ]
)
