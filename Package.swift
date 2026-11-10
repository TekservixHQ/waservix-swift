// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "WAservix",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "WAservix", targets: ["WAservix"]),
    ],
    targets: [
        .target(name: "WAservix"),
        .testTarget(name: "WAservixTests", dependencies: ["WAservix"]),
    ]
)
