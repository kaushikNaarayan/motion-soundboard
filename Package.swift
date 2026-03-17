// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Soundboard",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Soundboard",
            path: "Sources/Soundboard"
        )
    ]
)
