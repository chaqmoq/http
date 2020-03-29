// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "chaqmoq-http",
    products: [
        .library(name: "HTTP", targets: ["HTTP", "HTTPExample"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.15.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.1.1"),
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.11.0")
    ],
    targets: [
        .target(name: "HTTP", dependencies: ["Logging", "NIO", "NIOHTTP1", "NIOHTTP2", "NIOSSL"]),
        .target(name: "HTTPExample", dependencies: ["HTTP"]),
        .testTarget(name: "HTTPTests", dependencies: ["HTTP"])
    ],
    swiftLanguageVersions: [.v5]
)
