// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AVLiveBody",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "../../shared/AVLiveWire"),
    ],
    targets: [
        .executableTarget(
            name: "AVLiveBody",
            dependencies: [
                .product(name: "AVLiveWire", package: "AVLiveWire"),
            ],
            path: "Sources/AVLiveBody",
            resources: [
                .copy("Resources/smplx_faces.bin"),
                .copy("Resources/scene.metal"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .testTarget(
            name: "AVLiveBodyTests",
            dependencies: ["AVLiveBody"],
            path: "Tests/AVLiveBodyTests",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
