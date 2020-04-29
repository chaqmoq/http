# HTTP component
[![Swift](https://img.shields.io/badge/swift-5.1-brightgreen.svg)](https://swift.org/download/#releases) [![MIT License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](https://github.com/chaqmoq/http/blob/master/LICENSE/) [![Actions Status](https://github.com/chaqmoq/http/workflows/development/badge.svg)](https://github.com/chaqmoq/http/actions) [![codecov](https://codecov.io/gh/chaqmoq/http/branch/master/graph/badge.svg)](https://codecov.io/gh/chaqmoq/http)

## Installation

### Package.swift
```swift
let package = Package(
    // ...
    dependencies: [
        // Other packages...
        .package(url: "https://github.com/chaqmoq/http.git", .branch("master"))
    ],
    targets: [
        // Other targets...
        .target(name: "...", dependencies: ["HTTP"])
    ]
)
```

## Usage

```swift
import HTTP

let server = Server()
erver.onStart = { _ in
    print("Server has started")
}
server.onStop = {
    print("Server has stopped")
}
server.onError = { error, _ in
    print("Error: \(error)")
}
server.onReceive = { request, _ in
    // Do something...
    // Return String, Response, EventLoopFuture<String>, EventLoopFuture<Response>, etc
}

do {
    try server.start()
} catch {
    print(error)
}
```

### onReceive
```swift
// String
server.onReceive = { request, _ in
    return "Hello World"
}

// Response
server.onReceive = { request, _ in
    return Response(body: .init(string: "Hello World"))
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
        promise.succeed(Response(body: .init(string: "Hello World")))
    }

    return promise.futureResult
}
```

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change. Please, make sure to update tests as appropriate.

## License
[MIT](https://github.com/chaqmoq/http/blob/master/LICENSE)
