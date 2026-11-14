// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WakefulCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "WakefulCore", targets: ["WakefulCore"])],
    targets: [
        .target(name: "WakefulCore"),
        .testTarget(name: "WakefulCoreTests", dependencies: ["WakefulCore"]),
    ]
)
