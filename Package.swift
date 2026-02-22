// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Focus",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Focus", targets: ["Focus"])
    ],
    targets: [
        .executableTarget(
            name: "Focus",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "FocusTests",
            dependencies: ["Focus"],
            path: "Tests/FocusTests"
        )
    ]
)
