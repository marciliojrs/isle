import ProjectDescription

let project = Project(
    name: "IsleDemo",
    options: .options(
        defaultKnownRegions: ["en"],
        developmentRegion: "en"
    ),
    packages: [
        .local(path: .relativeToManifest(".."))
    ],
    targets: [
        .target(
            name: "IsleDemo",
            destinations: [.iPhone, .iPad],
            product: .app,
            bundleId: "dev.isle.demo",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(
                with: [
                    "NSCameraUsageDescription": "Isle Demo uses the camera to demonstrate the Dynamic Island camera panel.",
                    "UILaunchStoryboardName": "LaunchScreen",
                ]
            ),
            sources: ["IsleDemo/**"],
            resources: ["IsleDemo/LaunchScreen.storyboard", "IsleDemo/Assets.xcassets"],
            dependencies: [
                .package(product: "Isle")
            ]
        )
    ]
)
