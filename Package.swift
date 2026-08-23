// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BlockerAppCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "BlockerAppCore", targets: ["BlockerAppCore"]),
        .library(name: "MacCompanionCore", targets: ["MacCompanionCore"]),
        .executable(name: "BlockerMacCompanion", targets: ["BlockerMacCompanion"]),
    ],
    targets: [
        .target(name: "BlockerAppCore", path: "Sources/BlockerAppCore"),
        .target(name: "MacCompanionCore", path: "Sources/MacCompanionCore"),
        .executableTarget(
            name: "BlockerMacCompanion",
            dependencies: ["BlockerAppCore", "MacCompanionCore"],
            path: "Sources/BlockerMacCompanion"
        ),
        .testTarget(name: "BlockerAppCoreTests", dependencies: ["BlockerAppCore"], path: "Tests/BlockerAppCoreTests"),
        .testTarget(name: "MacCompanionCoreTests", dependencies: ["MacCompanionCore"], path: "Tests/MacCompanionCoreTests"),
    ]
)
