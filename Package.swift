// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppleZKProver",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AppleZKProver",
            targets: ["AppleZKProver"]
        ),
        .executable(
            name: "zkmetal-bench",
            targets: ["zkmetal-bench"]
        )
    ],
    targets: [
        .target(
            name: "AppleZKProver",
            resources: [
                .copy("Resources/HashMerkleKernels.metal")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "zkmetal-bench",
            dependencies: ["AppleZKProver"]
        ),
        .testTarget(
            name: "AppleZKProverTests",
            dependencies: ["AppleZKProver"]
        )
    ]
)
