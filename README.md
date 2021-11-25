# HTTP component
[![Swift](https://img.shields.io/badge/swift-5.3-brightgreen.svg)](https://swift.org/download/#releases) [![MIT License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](https://github.com/chaqmoq/http/blob/master/LICENSE/) [![Actions Status](https://github.com/chaqmoq/http/workflows/ci/badge.svg)](https://github.com/chaqmoq/http/actions) [![Codacy Badge](https://app.codacy.com/project/badge/Grade/e88a672e58bb436c97ebf8ecc678ea18)](https://www.codacy.com/gh/chaqmoq/http?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=chaqmoq/http&amp;utm_campaign=Badge_Grade) [![codecov](https://codecov.io/gh/chaqmoq/http/branch/master/graph/badge.svg?token=A2LEC0YCYL)](https://codecov.io/gh/chaqmoq/http) [![Documentation](https://github.com/chaqmoq/http/raw/gh-pages/badge.svg)](https://chaqmoq.dev/http/) [![Contributing](https://img.shields.io/badge/contributing-guide-brightgreen.svg)](https://github.com/chaqmoq/http/blob/master/CONTRIBUTING.md) [![Twitter](https://img.shields.io/badge/twitter-chaqmoqdev-brightgreen.svg)](https://twitter.com/chaqmoqdev)

## Installation
### Swift
Download and install [Swift](https://swift.org/download)

### Swift Package
```shell
mkdir MyApp
cd MyApp
swift package init --type executable // Creates an executable app named "MyApp"
```

#### Package.swift
```swift
// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "MyApp",
    dependencies: [
        .package(name: "chaqmoq-http", url: "https://github.com/chaqmoq/http.git", .branch("master"))
    ],
    targets: [
        .target(name: "MyApp", dependencies: [
            .product(name: "HTTP", package: "chaqmoq-http"),
        ]),
        .testTarget(name: "MyAppTests", dependencies: [
            .target(name: "MyApp")
        ])
    ]
)
```

### Build
```shell
swift build -c release
```

## Usage
```swift
import HTTP

let server = Server()
server.onStart = { _ in
    print("Server has started")
}
server.onStop = {
    print("Server has stopped")
}
server.onError = { error, _ in
    print("Error: \(error)")
}
server.onReceive = { request in
    // Return String, Response, etc
}
try server.start()
```

## Tests
```shell
swift test --enable-test-discovery --sanitize=thread
```
