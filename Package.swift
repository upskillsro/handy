// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReminderHelper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ReminderHelper", targets: ["ReminderHelper"])
    ],
    targets: [
        .executableTarget(
            name: "ReminderHelper",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
