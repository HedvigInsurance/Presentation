// swift-tools-version:5.3
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
            targets: ["Presentation"]),
        .library(
            name: "PresentationDebugSupport",
            targets: ["PresentationDebugSupport"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/hedviginsurance/Flow", .branch("master")),
        .package(url: "https://github.com/httpswift/swifter", .exact("1.5.0")),
        .package(url: "https://github.com/wickwirew/Runtime", .exact("2.2.2")),
    ],
    targets: [
        .target(
            name: "Presentation",
            dependencies: [
                .product(name: "Flow", package: "Flow")
            ],
            path: "Presentation"),
        .target(
            name: "PresentationDebugSupport",
            dependencies: [
                .product(name: "Flow", package: "Flow"),
                "Presentation",
                .product(name: "Runtime", package: "Runtime"),
                .product(name: "Swifter", package: "swifter")
            ],
            path: "PresentationDebugSupport"
        )
    ]
)
