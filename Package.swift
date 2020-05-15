// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "chaqmoq-http",
    products: [
        .library(name: "HTTP", targets: ["HTTP"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.17.0"),
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.12.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.7.2"),
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
