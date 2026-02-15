// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iTMUX",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "iTMUX",
            targets: ["iTMUX"]),
        .executable(
            name: "iTMUXApp",
            targets: ["iTMUXApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "iTMUX",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "Sources/iTMUX"
        ),
        .executableTarget(
            name: "iTMUXApp",
            dependencies: ["iTMUX"],
            path: "Sources/iTMUXApp"
        ),
        .testTarget(
            name: "iTMUXTests",
            dependencies: ["iTMUX"],
            path: "Tests/iTMUXTests"
        )
    ]
)
