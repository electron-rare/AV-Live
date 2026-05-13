// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AVLiveBody",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AVLiveBody",
            path: "Sources/AVLiveBody",
            resources: [
                .copy("Resources/smplx_faces.bin"),
            ]
        )
    ]
)
