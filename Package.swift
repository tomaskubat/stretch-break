// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StretchBreak",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "StretchBreak", targets: ["StretchBreak"])],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "StretchBreakCore", dependencies: ["CSQLite"]),
        .target(name: "StretchBreakMac", dependencies: ["StretchBreakCore"]),
        .executableTarget(name: "StretchBreak", dependencies: [
            "StretchBreakCore", "StretchBreakMac", .product(name: "Sparkle", package: "Sparkle")
        ]),
        .testTarget(name: "StretchBreakCoreTests", dependencies: ["StretchBreakCore", "CSQLite"]),
        .testTarget(name: "StretchBreakMacTests", dependencies: ["StretchBreakCore", "StretchBreakMac"]),
        .testTarget(name: "StretchBreakAppTests", dependencies: ["StretchBreak", "StretchBreakCore", "StretchBreakMac", "CSQLite"])
    ]
)
