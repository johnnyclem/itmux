// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TRex",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TRex",
            targets: ["TRex"]),
    ],
    dependencies: [
        // SSH library - you may need to swap this for NMSSH if it works better
        .package(url: "https://github.com/Frugghi/SwiftSSH.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "TRex",
            dependencies: ["SwiftSSH"]),
        .testTarget(
            name: "TRexTests",
            dependencies: ["TRex"]),
    ]
)
