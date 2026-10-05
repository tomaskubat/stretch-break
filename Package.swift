// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StretchBreak",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "StretchBreak", targets: ["StretchBreak"])],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "StretchBreakCore", dependencies: ["CSQLite"]),
        .target(name: "StretchBreakMac", dependencies: ["StretchBreakCore"]),
        .executableTarget(name: "StretchBreak", dependencies: ["StretchBreakCore", "StretchBreakMac"]),
        .testTarget(name: "StretchBreakCoreTests", dependencies: ["StretchBreakCore", "CSQLite"]),
        .testTarget(name: "StretchBreakMacTests", dependencies: ["StretchBreakCore", "StretchBreakMac"])
    ]
)
