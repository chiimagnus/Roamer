// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "Roamer",
    platforms: [
        .macOS(.v26)
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
