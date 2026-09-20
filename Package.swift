// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HingeForce",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "HingeForce",
            path: "Sources/HingeForce",
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                // Embeds Support/Info.plist in the executable itself, so the microphone usage
                // description is present however the app is launched (Xcode, `swift run`, or the
                // .app bundle). Without it macOS terminates the process on microphone access.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "\(Context.packageDirectory)/Support/Info.plist",
                ])
            ]
        ),
        .testTarget(name: "HingeForceTests", dependencies: ["HingeForce"], path: "Tests/HingeForceTests"),
    ]
)
