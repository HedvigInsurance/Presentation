// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Presentation",
    platforms: [
      .iOS(.v12)
    ],
    products: [
        .library(
            name: "Presentation",
            type: .dynamic,
            targets: ["Presentation"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hedviginsurance/Flow", .upToNextMajor(from: "1.8.6")),
    ],
    targets: [
        .target(
            name: "Presentation",
            dependencies: ["Flow"],
            path: "Presentation")
    ]
)
