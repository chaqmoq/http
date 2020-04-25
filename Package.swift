// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "chaqmoq-http",
    products: [
        .library(name: "HTTP", targets: ["HTTP"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.15.0"),
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.11.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.1.1"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.1.1")
    ],
    targets: [
        .target(name: "HTTP", dependencies: [
            "Logging",
            "NIO",
            "NIOHTTP1",
            "NIOHTTP2",
            "NIOHTTPCompression",
            "NIOSSL"
        ]),
        .testTarget(name: "HTTPTests", dependencies: ["HTTP", "AsyncHTTPClient"])
    ],
    swiftLanguageVersions: [.v5]
)
