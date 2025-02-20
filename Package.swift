// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HTTP",
    platforms: [.iOS(.v13),.watchOS(.v6),.macOS(.v10_15),.tvOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "HTTP",
            targets: ["HTTP"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/sutext/swift-json", from: "2.0.1"),
        .package(url: "https://github.com/sutext/swift-promise", from: "1.5.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
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
