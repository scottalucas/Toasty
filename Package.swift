// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Toasty",
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.3"),

        // 🔵 Swift ORM (queries, models, relations, etc) built on SQLite 3.
        .package(url: "https://github.com/vapor/fluent-postgresql.git", from: "1.0.0-rc.2.3"),
        .package(url: "https://github.com/vapor/leaf.git", from: "2.0.2")
    ],
    
    targets: [
        .target(name: "App", dependencies: ["FluentPostgreSQL", "Vapor", "Leaf"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)

