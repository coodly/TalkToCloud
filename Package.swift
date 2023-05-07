// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TalkToCloud",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "TalkToCloud",
            targets: ["TalkToCloud"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.5.0"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump.git", from: "0.10.2")
    ],
    targets: [
        .target(
            name: "TalkToCloud",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto")
            ]
        ),
        .testTarget(
            name: "TalkToCloudTests",
            dependencies: [
                "TalkToCloud",
                
                .product(name: "CustomDump", package: "swift-custom-dump")
            ]
        ),
    ]
)
