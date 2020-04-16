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
server.onReceive = { request in
    return Response(body: .init(string: "Hello World"))
}

do {
    try server.start()
} catch {
    print(error)
}

```

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change. Please, make sure to update tests as appropriate.

## License
[MIT](https://github.com/chaqmoq/http/blob/master/LICENSE)
