// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AVLiveBody",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "AVLiveBody",
            path: "Sources/AVLiveBody",
            resources: [
                .copy("Resources/smplx_faces.bin"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        )
    ]
)
