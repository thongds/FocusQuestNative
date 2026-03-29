// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FocusQuest",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "FocusQuest",
            path: "Sources/FocusQuest"
        )
    ]
)
