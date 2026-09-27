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
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
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
        .testTarget(
            name: "NativelyCoreTests",
            dependencies: ["NativelyCore"],
            path: "Tests/NativelyCoreTests"
        ),
        .testTarget(
            name: "NativelySecurityTests",
            dependencies: ["NativelySecurity"],
            path: "Tests/NativelySecurityTests"
        ),
        .testTarget(
            name: "NativelyDatabaseTests",
            dependencies: ["NativelyDatabase"],
            path: "Tests/NativelyDatabaseTests"
        )
    ]
)
