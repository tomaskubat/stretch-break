// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StretchBreakPrototype",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "StretchBreakPrototype", targets: ["StretchBreakPrototype"])],
    targets: [
        .target(name: "PrototypeCore"),
        .executableTarget(name: "StretchBreakPrototype", dependencies: ["PrototypeCore"]),
        .testTarget(name: "PrototypeCoreTests", dependencies: ["PrototypeCore"])
    ]
)
