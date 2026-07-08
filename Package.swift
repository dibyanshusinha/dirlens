// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DirLens",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DirLens",
            path: "Sources/DirLens"
        )
    ]
)
