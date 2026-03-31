// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FocusQuest",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "FocusQuest",
            path: "Sources/FocusQuest",
            exclude: [
                "Resources/Info.plist",
                "Resources/.DS_Store",
                "Resources/Assets.xcassets/.DS_Store"
            ],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/FocusQuest/Resources/Info.plist"
                ])
            ]
        )
    ]
)
