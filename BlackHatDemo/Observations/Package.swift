// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Observations",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "BChain.git", from:"0.0.11"),
        .package(url: "https://github.com/vapor/crypto.git", from: "3.3.3"),
        .package(url: "https://github.com/swift-aws/aws-sdk-swift.git", from: "3.0.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Observations",
            dependencies: ["SQS","BChain","Crypto"]),
        .testTarget(
            name: "ObservationsTests",
            dependencies: ["Observations"]),
    ]
)
