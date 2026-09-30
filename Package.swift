// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "status-bar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "status-bar", targets: ["status-bar"])
    ],
    targets: [
        .executableTarget(
            name: "status-bar",
            path: "Sources/status-bar",
            exclude: [
                "Resources"
            ]
        ),
        .testTarget(
            name: "status-bar-tests",
            dependencies: ["status-bar"],
            path: "Tests/status-bar-tests"
        )
    ]
)
