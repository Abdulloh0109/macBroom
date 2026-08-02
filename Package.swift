// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacBroom",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacBroom",
            path: "Sources/MacBroom"
        )
    ]
)
