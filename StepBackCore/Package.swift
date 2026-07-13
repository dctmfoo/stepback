// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "StepBackCore",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "StepBackCore",
            targets: ["StepBackCore"]
        )
    ],
    targets: [
        .target(
            name: "StepBackCore"
        ),
        .testTarget(
            name: "StepBackCoreTests",
            dependencies: ["StepBackCore"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
