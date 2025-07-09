// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Vapi",
    platforms: [
        .iOS(.v13),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "Vapi",
            targets: ["Vapi"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/daily-co/daily-client-ios", from: "0.31.0"),
    ],
    targets: [
        .target(
            name: "Vapi",
            dependencies: [
                .product(name: "Daily", package: "daily-client-ios")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "VapiTests",
            dependencies: ["Vapi"],
            path: "Tests"
        ),
    ]
)
