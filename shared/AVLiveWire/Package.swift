// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AVLiveWire",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(name: "AVLiveWire", targets: ["AVLiveWire"]),
    ],
    targets: [
        .target(name: "AVLiveWire"),
        .testTarget(name: "AVLiveWireTests", dependencies: ["AVLiveWire"]),
    ]
)
