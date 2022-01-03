// swift-tools-version: 5.5

// WARNING:
// This file is automatically generated.
// Do not edit it by hand because the contents will be replaced.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Trefo",
    platforms: [
        .iOS("15.2")
    ],
    products: [
        .iOSApplication(
            name: "Trefo",
            targets: ["AppModule"],
            bundleIdentifier: "ru.pukhanov.Trefo",
            teamIdentifier: "BFJQQT3YDX",
            displayVersion: "1.1",
            bundleVersion: "2",
            iconAssetName: "AppIcon",
            accentColorAssetName: "AccentColor",
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [
                .photoLibrary(purposeString: "Trefo needs Photo Library access to move your travel photos into separate albums")
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/TelemetryDeck/SwiftClient", "1.1.6"..<"2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            dependencies: [
                .product(name: "TelemetryClient", package: "swiftclient")
            ],
            path: "."
        )
    ]
)