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
            // Resources/ is assembled into the .app by script/release.sh
            // (entitlements, asset catalog, PrivacyInfo.xcprivacy) rather than
            // by SwiftPM, so it is excluded here.
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
