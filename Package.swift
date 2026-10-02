// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Roamer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "roamer", targets: ["RoamerCLI"])
    ],
    targets: [
        .target(
            name: "RoamerPrivateABI",
            publicHeadersPath: "include"
        ),
        .target(
            name: "RoamerCore",
            dependencies: ["RoamerPrivateABI"]
        ),
        .executableTarget(
            name: "RoamerCLI",
            dependencies: ["RoamerCore"]
        ),
        .testTarget(
            name: "RoamerCoreTests",
            dependencies: ["RoamerCore"]
        )
    ]
)
