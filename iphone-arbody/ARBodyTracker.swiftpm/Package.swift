// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ARBodyTracker",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .executable(name: "ARBodyTracker", targets: ["ARBodyTracker"]),
    ],
    dependencies: [
        .package(path: "../../shared/AVLiveWire"),
    ],
    targets: [
        .executableTarget(
            name: "ARBodyTracker",
            dependencies: [
                .product(name: "AVLiveWire", package: "AVLiveWire"),
            ],
            path: "Sources/ARBodyTracker"
        ),
    ]
)
