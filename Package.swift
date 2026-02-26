// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Helpy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Helpy", targets: ["Helpy"])
    ],
    targets: [
        .executableTarget(
            name: "Helpy",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "HelpyTests",
            dependencies: ["Helpy"],
            path: "Tests/HelpyTests"
        )
    ]
)
