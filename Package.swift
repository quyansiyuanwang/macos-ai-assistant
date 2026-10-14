// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AiSiri",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../pi-ai-swift"),
        .package(path: "../pi-agent-swift"),
    ],
    targets: [
        .executableTarget(
            name: "AiSiri",
            dependencies: [
                .product(name: "PiAI", package: "pi-ai-swift"),
                .product(name: "PiAgentCore", package: "pi-agent-swift"),
            ],
            path: "Sources/AiSiri",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
