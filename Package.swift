// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Glean",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Glean",
            path: "Sources/Glean",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Speech"),
                .linkedFramework("UserNotifications"),
            ]
        ),
        .testTarget(
            name: "GleanTests",
            dependencies: ["Glean"],
            path: "Tests/GleanTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
