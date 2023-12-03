// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Vapi",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "Vapi",
            targets: ["Vapi"]),
    ],
    dependencies: [
        .package(url: "https://github.com/daily-co/daily-client-ios", from: "0.2.0"),
    ],
    targets: [
        .target(
            name: "Vapi",
            dependencies: [
                .product(name: "Daily", package: "daily-client-ios")
            ]),
        .testTarget(
            name: "VapiTests",
            dependencies: ["Vapi"]),
    ]
)