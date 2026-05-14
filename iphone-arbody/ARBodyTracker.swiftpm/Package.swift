// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ARBodyTracker",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .executable(name: "ARBodyTracker", targets: ["ARBodyTracker"]),
    ],
    targets: [
        .executableTarget(
            name: "ARBodyTracker",
            path: "Sources/ARBodyTracker"
        ),
    ]
)
