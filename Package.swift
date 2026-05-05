// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BlockerAppCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "BlockerAppCore", targets: ["BlockerAppCore"]),
    ],
    targets: [
        .target(name: "BlockerAppCore", path: "Sources/BlockerAppCore"),
        .testTarget(name: "BlockerAppCoreTests", dependencies: ["BlockerAppCore"], path: "Tests/BlockerAppCoreTests"),
    ]
)
