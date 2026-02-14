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
    ],
    dependencies: [
        .package(url: "https://github.com/Frugghi/NMSSH.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "iTMUX",
            dependencies: [
                // Link against NMSSH product provided by the dependency
                .product(name: "NMSSH", package: "NMSSH")
            ],
            path: "Sources"
        )
    ]
)
