// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "topiary-bar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "topiary-bar", targets: ["topiary-bar"])
    ],
    targets: [
        .executableTarget(
            name: "topiary-bar",
            path: "Sources/topiary-bar",
            exclude: [
                "Resources"
            ]
        ),
        .testTarget(
            name: "topiary-bar-tests",
            dependencies: ["topiary-bar"],
            path: "Tests/topiary-bar-tests"
        )
    ]
)
