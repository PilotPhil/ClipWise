// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClipWiseMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClipWiseMac", targets: ["ClipWiseMac"])
    ],
    targets: [
        .executableTarget(
            name: "ClipWiseMac",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
