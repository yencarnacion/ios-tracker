// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HabitCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "HabitCore", targets: ["HabitCore"])],
    targets: [
        .target(name: "HabitCore", path: "HabitTracker/Core"),
        .testTarget(name: "HabitCoreTests", dependencies: ["HabitCore"], path: "Tests/HabitCoreTests")
    ]
)
