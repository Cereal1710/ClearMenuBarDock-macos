// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClearMenuBarDock",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClearMenuBarDock", targets: ["ClearMenuBarDock"])
    ],
    targets: [
        .executableTarget(
            name: "ClearMenuBarDock",
            path: "Sources"
        )
    ]
)
