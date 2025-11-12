// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EntityKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "EntityKit", targets: ["EntityKit"]),
        .library(name: "EntityAuthUI", targets: ["EntityAuthUI"]),
        .library(name: "EntityDocsSwift", targets: ["EntityDocsSwift"])
    ],
    dependencies: [
        .package(url: "https://github.com/entityauth/convex-swift.git", from: "0.1.0"),
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.3.0")
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
                "EntityAuthRealtime",
                // Re-export UI so consumers can just `import EntityKit`
                "EntityAuthUI"
            ]
        ),
        .target(
            name: "EntityAuthUI",
            dependencies: [
                "EntityAuthCore",
                "EntityAuthNetworking",
                "EntityAuthDomain",
                "EntityAuthRealtime",
                "EntityDocsSwift"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "EntityDocsSwift",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            resources: [
                .copy("Resources/past"),
                .copy("Resources/entity-auth")
            ]
        ),
        .testTarget(
            name: "EntityKitTests",
            dependencies: [
                "EntityKit",
                "EntityAuthCore",
                "EntityAuthNetworking",
                "EntityAuthDomain",
                "EntityAuthRealtime"
            ]
        )
    ]
)
