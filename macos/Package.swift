// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NativelyMac",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "NativelyCore", targets: ["NativelyCore"]),
        .library(name: "NativelySecurity", targets: ["NativelySecurity"]),
        .library(name: "NativelyDatabase", targets: ["NativelyDatabase"]),
        .library(name: "NativelyAudio", targets: ["NativelyAudio"]),
        .library(name: "NativelyVision", targets: ["NativelyVision"]),
        .library(name: "NativelyAI", targets: ["NativelyAI"]),
        .library(name: "NativelyUI", targets: ["NativelyUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.14.0")
    ],
    targets: [
        .target(
            name: "NativelyCore",
            dependencies: [],
            path: "Sources/NativelyCore"
        ),
        .target(
            name: "NativelySecurity",
            dependencies: ["NativelyCore"],
            path: "Sources/NativelySecurity"
        ),
        .target(
            name: "NativelyDatabase",
            dependencies: [
                "NativelyCore",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/NativelyDatabase"
        ),
        .target(
            name: "NativelyAudio",
            dependencies: [
                "NativelyCore",
                "NativelyDatabase",
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources/NativelyAudio"
        ),
        .target(
            name: "NativelyVision",
            dependencies: [
                "NativelyCore",
                "NativelyDatabase"
            ],
            path: "Sources/NativelyVision"
        ),
        .target(
            name: "NativelyAI",
            dependencies: [
                "NativelyCore",
                "NativelyDatabase",
                "NativelySecurity",
                "NativelyVision"
            ],
            path: "Sources/NativelyAI"
        ),
        .target(
            name: "NativelyUI",
            dependencies: [
                "NativelyCore",
                "NativelyDatabase",
                "NativelySecurity",
                "NativelyAudio",
                "NativelyVision",
                "NativelyAI",
            ],
            path: "Sources/NativelyUI"
        ),
        .testTarget(
            name: "NativelyCoreTests",
            dependencies: [
                "NativelyCore",
                "NativelyDatabase"
            ],
            path: "Tests/NativelyCoreTests"
        ),
        .testTarget(
            name: "NativelySecurityTests",
            dependencies: [
                "NativelySecurity",
                "NativelyDatabase"
            ],
            path: "Tests/NativelySecurityTests"
        ),
        .testTarget(
            name: "NativelyDatabaseTests",
            dependencies: ["NativelyDatabase"],
            path: "Tests/NativelyDatabaseTests"
        ),
        .testTarget(
            name: "NativelyAudioTests",
            dependencies: ["NativelyAudio"],
            path: "Tests/NativelyAudioTests"
        ),
        .testTarget(
            name: "NativelyVisionTests",
            dependencies: ["NativelyVision"],
            path: "Tests/NativelyVisionTests"
        ),
        .testTarget(
            name: "NativelyAITests",
            dependencies: ["NativelyAI"],
            path: "Tests/NativelyAITests"
        ),
        .testTarget(
            name: "NativelyUITests",
            dependencies: [
                "NativelyUI",
                "NativelyDatabase",
                "NativelyAudio"
            ],
            path: "Tests/NativelyUITests"
        )
    ]
)
