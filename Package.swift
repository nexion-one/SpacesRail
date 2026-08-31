// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpacesRail",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SpacesRail", targets: ["SpacesRail"]),
        .executable(name: "SpacesRailDemo", targets: ["SpacesRailDemo"]),
    ],
    targets: [
        .target(name: "SpacesRail"),
        .executableTarget(name: "SpacesRailDemo", dependencies: ["SpacesRail"]),
    ]
)
