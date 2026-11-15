// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FastLangSwitch",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "FastLangSwitch", targets: ["FastLangSwitch"])],
    targets: [
        .target(name: "SwitchCore"),
        .executableTarget(name: "FastLangSwitch", dependencies: ["SwitchCore"]),
        .testTarget(name: "SwitchCoreTests", dependencies: ["SwitchCore"])
    ]
)
