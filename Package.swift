// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Isle",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "Isle",
            targets: ["Isle"]
        )
    ],
    targets: [
        .target(
            name: "Isle",
            path: "Sources/Isle"
        ),
        .testTarget(
            name: "IsleTests",
            dependencies: ["Isle"],
            path: "Tests/IsleTests"
        )
    ]
)
