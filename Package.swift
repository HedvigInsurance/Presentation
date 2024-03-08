// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Presentation",
    platforms: [
      .iOS(.v13)
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
        .package(url: "https://github.com/hedviginsurance/Flow", .upToNextMajor(from: "1.8.7")),
        .package(url: "https://github.com/httpswift/Swifter", .exact("1.5.0")),
        .package(url: "https://github.com/wickwirew/Runtime", .branch("swift-5-10-fix")),
    ],
    targets: [
        .target(
            name: "Presentation",
            dependencies: [
                .product(name: "Flow", package: "Flow")
            ],
            path: "Presentation",
            exclude: ["Info.plist"]
        ),
        .target(
            name: "PresentationDebugSupport",
            dependencies: [
                "Presentation",
                .product(name: "Runtime", package: "Runtime"),
                .product(name: "Swifter", package: "Swifter")
            ],
            path: "PresentationDebugSupport"
        )
    ]
)
