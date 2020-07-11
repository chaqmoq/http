# HTTP component
[![Swift](https://img.shields.io/badge/swift-5.1-brightgreen.svg)](https://swift.org/download/#releases) [![MIT License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](https://github.com/chaqmoq/http/blob/master/LICENSE/) [![Actions Status](https://github.com/chaqmoq/http/workflows/development/badge.svg)](https://github.com/chaqmoq/http/actions) [![Codacy Badge](https://app.codacy.com/project/badge/Grade/e88a672e58bb436c97ebf8ecc678ea18)](https://www.codacy.com/gh/chaqmoq/http?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=chaqmoq/http&amp;utm_campaign=Badge_Grade) [![Contributing](https://img.shields.io/badge/contributing-guide-brightgreen.svg)](https://github.com/chaqmoq/http/blob/master/CONTRIBUTING.md) [![Twitter](https://img.shields.io/badge/twitter-chaqmoqdev-brightgreen.svg)](https://twitter.com/chaqmoqdev)

## Installation
### Swift
Download and install [Swift](https://swift.org/download)

### Swift Package
```shell
mkdir MyApp
cd MyApp
swift package init --type executable // Creates an executable app named "MyApp"
```

### Package.swift
```swift
// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "MyApp",
    dependencies: [
        .package(url: "https://github.com/chaqmoq/http.git", .branch("master"))
    ],
    targets: [
        .target(name: "MyApp", dependencies: ["HTTP"]),
        .testTarget(name: "MyAppTests", dependencies: ["MyApp"])
    ]
)
```

### Build
```shell
swift build -c release
```

## Usage
### main.swift

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
server.onReceive = { request, _ in
    // Return String, Response, EventLoopFuture<String>, EventLoopFuture<Response>, etc
}
try server.start()
```

#### onReceive
```swift
// String
server.onReceive = { request, _ in
    "Hello World"
}

// Response
server.onReceive = { request, _ in
    Response("Hello World")
}

// EventLoopFuture<String>
server.onReceive = { request, eventLoop in
    // Some async operation that returns EventLoopFuture<String>
    let promise = eventLoop.makePromise(of: String.self)
    eventLoop.execute {
        promise.succeed("Hello World")
    }

    return promise.futureResult
}

// EventLoopFuture<Response>
server.onReceive = { request, eventLoop in
    // Some async operation that returns EventLoopFuture<Response>
    let promise = eventLoop.makePromise(of: Response.self)
    eventLoop.execute {
        promise.succeed(Response("Hello World"))
    }

    return promise.futureResult
}
```

### Run
```shell
swift run
```

### Tests
```shell
swift test --enable-test-discovery --sanitize=thread
```
