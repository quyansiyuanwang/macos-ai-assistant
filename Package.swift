// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AiSiri",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AiSiri",
            path: "Sources/AiSiri",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
