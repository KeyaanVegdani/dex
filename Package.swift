// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HingeForce",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "HingeForce", path: "Sources/HingeForce")
    ]
)
