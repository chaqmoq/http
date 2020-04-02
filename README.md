# HTTP Component

This is a part of Chaqmoq Web Framework in Swift language

## Installation

```bash
dependencies: [
    .package(url: "https://github.com/chaqmoq/http.git", .branch("master"))
],
targets: [
    .target(name: "YourTarget", dependencies: ["HTTP"])
]
```

## Usage

```swift
import HTTP

let server = Server()
server.onReceive = { request in
    return Response(body: .init(string: "Hello World"))
}

do {
    try server.start()
} catch {
    fatalError("Failed to start server: \(error)")
}
```

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change. Please, make sure to update tests as appropriate.

## License
[MIT](https://choosealicense.com/licenses/mit/)
