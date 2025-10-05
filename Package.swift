// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EntityKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "EntityKit", targets: ["EntityKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/entityauth/convex-swift.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "EntityAuthCore",
            dependencies: []
        ),
        .target(
            name: "EntityAuthNetworking",
            dependencies: ["EntityAuthCore"]
        ),
        .target(
            name: "EntityAuthDomain",
            dependencies: [
                "EntityAuthCore",
                "EntityAuthNetworking",
                "EntityAuthRealtime"
            ]
        ),
        .target(
            name: "EntityAuthRealtime",
            dependencies: [
                "EntityAuthCore",
                .product(name: "ConvexMobile", package: "convex-swift")
            ]
        ),
        .target(
            name: "EntityKit",
            dependencies: [
                "EntityAuthCore",
                "EntityAuthNetworking",
                "EntityAuthDomain",
                "EntityAuthRealtime"
            ]
        ),
        .testTarget(name: "EntityKitTests", dependencies: ["EntityKit"])
    ]
)
