// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Presentation",
    products: [
        .library(
            name: "Presentation",
            targets: ["Presentation"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hedviginsurance/flow", .branch("master")),
    ],
    targets: [
        .target(
            name: "Presentation",
            dependencies: []),
        .testTarget(
            name: "PresentationTests",
            dependencies: ["Presentation"]),
    ]
)
