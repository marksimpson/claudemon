// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Claudemon",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "ClaudemonKit",
            path: "Sources/ClaudemonKit"
        ),
        .executableTarget(
            name: "Claudemon",
            dependencies: ["ClaudemonKit"],
            path: "Sources/Claudemon"
        ),
        .testTarget(
            name: "ClaudemonKitTests",
            dependencies: ["ClaudemonKit"],
            path: "Tests/ClaudemonKitTests"
        ),
    ]
)
