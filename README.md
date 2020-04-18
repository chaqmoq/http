# HTTP Component

This is a part of Chaqmoq web framework in Swift

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
server.onStart = {
    print("Server has started")
}
server.onStop = {
    print("Server has stopped")
}
server.onError = { error in
    print("Server error: \(error)")
}

do {
    try server.start()
} catch {
    print(error)
}
```

```swift
# 1. Return String (sync)
server.onReceive = { request, _ in
    return "Hello World"
}
```

```swift
# 2. Return Response (sync)
server.onReceive = { request, _ in
    return Response(body: .init(string: "Hello World"))
}
```

```swift
# 3. Return EventLoopFuture<String> (async)
server.onReceive = { request, eventLoop in
    # Some async request that returns EventLoopFuture<T>
    let promise = eventLoop.makePromise(of: String.self)
    eventLoop.execute {
        promise.succeed("Hello World")
    }

    return promise.futureResult
}
```

```swift
# 4. Return EventLoopFuture<Response> (async)
server.onReceive = { request, eventLoop in
    # Some async request that returns EventLoopFuture<T>
    let promise = eventLoop.makePromise(of: String.self)
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
