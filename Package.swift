// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "chaqmoq-http",
    platforms: [
        .iOS(.v13),
        .macOS(.v12),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "HTTP", targets: ["HTTP"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.0.0"),
        .package(name: "AnyCodable", url: "https://github.com/sukhrobkhakimov/AnyCodable.git", from: "0.6.0")
    ],
    targets: [
        .target(name: "HTTP", dependencies: [
            .product(name: "AnyCodable", package: "AnyCodable"),
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
            .product(name: "NIOHTTP2", package: "swift-nio-http2"),
            .product(name: "NIOHTTPCompression", package: "swift-nio-extras"),
            .product(name: "NIOSSL", package: "swift-nio-ssl")
        ]),
        .testTarget(name: "HTTPTests", dependencies: [
            .target(name: "HTTP"),
            .product(name: "AsyncHTTPClient", package: "async-http-client")
        ])
    ],
    swiftLanguageVersions: [.v5]
)
