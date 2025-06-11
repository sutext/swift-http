// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-http",
    platforms: [.iOS(.v13),.watchOS(.v6),.macOS(.v10_15),.tvOS(.v13)],
    products: [
        .library(
            name: "HTTP",
            targets: ["HTTP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sutext/swift-json", from: "2.4.2"),
        .package(url: "https://github.com/sutext/swift-promise", from: "2.2.0")
    ],
    targets: [
        .target(
            name: "HTTP",
            dependencies: [
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Promise", package: "swift-promise"),
            ]),
        .testTarget(
            name: "HTTPTests",
            dependencies: ["HTTP"]),
    ]
)
