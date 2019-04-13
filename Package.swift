// swift-tools-version:4.0
import PackageDescription


let package = Package(
    name: "ToastyBackend",
    products: [
        .library(name: "ToastyBackend", targets: ["App"]),
    ],
    dependencies: [
	.package(url: "https://github.com/vapor/vapor.git", from: "3.3.0-rc"),
	.package(url: "https://github.com/vapor/fluent-postgresql.git", from: "1.0.0-rc"),
	.package(url: "https://github.com/vapor/leaf.git", from: "3.0.2-rc")

    ],
    targets: [
        .target(name: "App", dependencies: ["Vapor", "FluentPostgreSQL", "Leaf"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)
