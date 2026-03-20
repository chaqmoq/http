<div align="center">
    <h1>HTTP</h1>
    <p>
        <a href="https://swift.org/download/#releases"><img src="https://img.shields.io/badge/swift-5.10+-brightgreen.svg" /></a>
        <a href="https://github.com/chaqmoq/http/blob/master/LICENSE/"><img src="https://img.shields.io/badge/license-MIT-brightgreen.svg" /></a>
        <a href="https://github.com/chaqmoq/http/actions"><img src="https://github.com/chaqmoq/http/workflows/ci/badge.svg" /></a>
        <a href="https://github.com/chaqmoq/http/blob/master/CONTRIBUTING.md"><img src="https://img.shields.io/badge/contributing-guide-brightgreen.svg" /></a>
        <a href="https://t.me/chaqmoqdev"><img src="https://img.shields.io/badge/telegram-chaqmoqdev-brightgreen.svg" /></a>
    </p>
    <p>A non-blocking, event-driven HTTP/1.1 and HTTP/2 server package written in <a href="https://swift.org">Swift</a> and powered by <a href="https://github.com/apple/swift-nio">SwiftNIO</a>. This is one of the core packages of <a href="https://chaqmoq.dev">Chaqmoq</a>.</p>
</div>

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Server Configuration](#server-configuration)
  - [Body size limits](#body-size-limits)
  - [Compression and decompression](#compression-and-decompression)
- [Lifecycle Callbacks](#lifecycle-callbacks)
- [Handling Requests](#handling-requests)
  - [Reading headers](#reading-headers)
  - [Query parameters](#query-parameters)
  - [Form parameters](#form-parameters)
  - [Uploaded files](#uploaded-files)
  - [Cookies](#cookies)
  - [Request attributes](#request-attributes)
- [Building Responses](#building-responses)
  - [Setting headers](#setting-headers)
  - [Status codes](#status-codes)
  - [Response cookies](#response-cookies)
- [Body](#body)
  - [Typed JSON decoding](#typed-json-decoding)
- [Body Streaming](#body-streaming)
  - [Enabling streaming](#enabling-streaming)
  - [Collecting the full body](#collecting-the-full-body)
  - [Iterating chunks directly](#iterating-chunks-directly)
  - [Error handling](#error-handling)
- [HTTP/2 Server Push](#http2-server-push)
- [Middleware](#middleware)
- [Error Middleware](#error-middleware)
- [Built-in Middleware](#built-in-middleware)
  - [CORSMiddleware](#corsmiddleware)
  - [HTTPMethodOverrideMiddleware](#httpmethodoverridemiddleware)
- [WebSocket](#websocket)
- [Unix Domain Sockets](#unix-domain-sockets)
- [HTTPS / TLS](#https--tls)
- [Full Example](#full-example)
- [License](#license)

## Requirements

| Platform | Minimum version |
|----------|----------------|
| macOS | 12 |
| Ubuntu | 20.04 |

Requires **Swift 5.10** or later.

## Installation

Add the package to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/chaqmoq/http.git", branch: "master")
]
```

Then add `"HTTP"` to your target's dependencies:

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "HTTP", package: "http")
])
```

## Quick Start

```swift
import HTTP

let server = Server()

server.onReceive = { request in
    Response("Hello, World!")
}

try server.start() // blocks until stop() is called
```

`start()` binds the socket and blocks the calling thread. Run it on a dedicated thread or background queue in applications that need to do other work concurrently.

## Server Configuration

`Server` is initialised with a `Server.Configuration` value. Every property has a sensible default, so you only need to override what you need.

```swift
let config = Server.Configuration(
    identifier: "com.example.api",
    host: "0.0.0.0",
    port: 8080,
    serverName: "MyAPI/1.0",
    tls: nil,
    supportsVersions: [.one, .two],
    supportsPipelining: false,
    numberOfThreads: System.coreCount,
    backlog: 256,
    reuseAddress: true,
    tcpNoDelay: true,
    maxMessagesPerRead: 16,
    maxBodySize: 10_485_760,           // reject bodies larger than 10 MB
    streamingBodyThreshold: 1_048_576, // stream bodies larger than 1 MB
    requestDecompression: .init(limit: .ratio(10), isEnabled: true),
    responseCompression: .init(isEnabled: true)
)

let server = Server(configuration: config)
```

Two computed properties derive the full address from the configuration:

```swift
config.scheme // "http" (or "https" when TLS is configured)
config.socketAddress // "http://127.0.0.1:8080"
```

### Body size limits

`maxBodySize` rejects any request whose body exceeds the given byte count. `streamingBodyThreshold` controls when large bodies are streamed instead of buffered — see [Body Streaming](#body-streaming) for details.

```swift
// Hard reject anything above 10 MB
Server.Configuration(maxBodySize: 10_485_760)

// Buffer bodies ≤ 1 MB; stream everything larger
Server.Configuration(streamingBodyThreshold: 1_048_576)

// Combine both: stream large bodies, reject extreme ones
Server.Configuration(maxBodySize: 50_000_000, streamingBodyThreshold: 1_048_576)
```

### Compression and decompression

Response compression (gzip/deflate) and request decompression are both enabled by default.

```swift
// Disable response compression
Server.Configuration(responseCompression: .init(isEnabled: false))

// Limit decompressed bodies to 10 MB
Server.Configuration(requestDecompression: .init(limit: .size(10_485_760)))

// No decompression limit
Server.Configuration(requestDecompression: .init(limit: .none))

// Limit by inflation ratio (decompressed ÷ compressed size)
Server.Configuration(requestDecompression: .init(limit: .ratio(20)))
```

## Lifecycle Callbacks

```swift
server.onStart = { eventLoop in
    print("Listening on \(server.configuration.socketAddress)")
}

server.onStop = {
    print("Server stopped")
}

server.onError = { error, eventLoop in
    print("Channel error: \(error)")
}
```

To stop the server from another thread:

```swift
try server.stop()
```

## Handling Requests

Assign a closure to `onReceive`. Return any `Encodable` value — if it is not a `Response` it is automatically wrapped in one using its string representation.

```swift
server.onReceive = { request in
    let method = request.method // .GET, .POST, .PUT, …
    let path = request.uri.path // "/users/42"
    let version = request.version // Version(major: 1, minor: 1)
    let locale = request.locale // derived from Accept-Language header

    return Response("OK")
}
```

### Reading headers

```swift
let contentType = request.headers.get(.contentType)
let accept = request.headers.get(.accept)
let custom = request.headers.get("X-My-Header")
```

### Query parameters

```swift
// URL: /search?q=swift&page=2
let query: String? = request.uri.getQueryParameter("q") // "swift"
let page: Int? = request.uri.getQueryParameter("page") // 2
```

### Form parameters

Parameters are automatically parsed from `application/x-www-form-urlencoded` and `multipart/form-data` bodies.

```swift
let username: String? = request.getParameter("username")
let age: Int? = request.getParameter("age")
```

### Uploaded files

```swift
if let avatar = request.files["avatar"] {
    print(avatar.filename) // "photo.png"
    let data = avatar.data // Foundation.Data
}
```

### Cookies

```swift
if request.hasCookie(named: "sessionId") {
    // ...
}

for cookie in request.cookies {
    print("\(cookie.name) = \(cookie.value)")
}
```

### Request attributes

Attributes let middleware attach typed values to a request without modifying its headers or body.

```swift
// In middleware:
request.setAttribute("userId", value: 42)

// In the handler (or later middleware):
let userId: Int? = request.getAttribute("userId")
```

## Building Responses

`Response` can be created from a string, `Data`, or a `Body`:

```swift
Response() // 200 OK, empty body
Response("Created", status: .created) // 201 Created, text body
Response(pngData, status: .ok) // Data body
Response(Body(bytes: rawBytes)) // byte array body
```

### Setting headers

```swift
var response = Response("Hello")
response.headers.set(.init(name: .contentType, value: "text/plain; charset=utf-8"))
response.headers.set(.init(name: "X-Request-Id", value: "abc-123"))
```

### Status codes

All standard IANA status codes are available as enum cases:

```swift
response.status = .ok // 200
response.status = .created // 201
response.status = .noContent // 204
response.status = .badRequest // 400
response.status = .unauthorized // 401
response.status = .notFound // 404
response.status = .internalServerError // 500

print(response.status.code) // 200
print(response.status.reason) // "OK"
print(response.status) // "200 OK"
```

### Response cookies

```swift
var response = Response("Logged in")

response.setCookie(Cookie(
    name: "sessionId",
    value: "abc123",
    maxAge: 3600,
    path: "/",
    isSecure: true,
    isHTTPOnly: true,
    sameSite: .lax
))

response.clearCookie(named: "sessionId") // remove one cookie
response.clearCookies() // remove all Set-Cookie headers
```

Cookie prefixes `__Host-` and `__Secure-` are enforced automatically:

- `__Host-` forces `domain = nil`, `path = "/"`, and `isSecure = true`.
- `__Secure-` forces `isSecure = true`.

## Body

`Body` stores content in a NIO `ByteBuffer` — a reference-counted, pooled byte store. No extra heap allocation occurs when NIO passes a request body straight through the pipeline.

```swift
let body = Body(string: "Hello")
body.string // "Hello" (falls back to "" on invalid UTF-8)
body.data // Foundation.Data
body.bytes // [UInt8]
body.buffer // NIO ByteBuffer (zero-copy)
body.count // 5
body.isEmpty // false

// Construct directly from a NIO ByteBuffer (no copy)
let body = Body(byteBuffer)

// Mutation
var body = Body()
body.append(string: "chunk one ")
body.append(data: moreData)
body.append(bytes: [0x0A])
```

### Typed JSON decoding

Use `decode(_:using:)` to decode the body as a `Decodable` type without going through `body.json`:

```swift
struct LoginRequest: Decodable {
    let username: String
    let password: String
}

server.onReceive = { request in
    let login = try request.body.decode(LoginRequest.self)
    // ... authenticate ...
    return Response("OK")
}
```

## Body Streaming

By default every request body is fully buffered in memory before `onReceive` is called, so `request.body` is always ready to use. For large uploads (files, binary blobs, server-sent payloads) you can instead receive the body as an `AsyncSequence` of `ByteBuffer` chunks, processing or forwarding each piece as it arrives without holding the entire content in memory at once.

### Enabling streaming

Set `streamingBodyThreshold` on the server configuration. Bodies whose `Content-Length` exceeds the threshold — or whose length is unknown (chunked transfer encoding) — are streamed. Bodies at or below the threshold continue to be fully buffered.

```swift
var config = Server.Configuration()
config.streamingBodyThreshold = 1_048_576  // stream bodies > 1 MB

let server = Server(configuration: config)
```

### Collecting the full body

`Request.collectBody(maxSize:)` is the idiomatic way to consume a streaming body when you need the complete content. It works in both buffered and streaming mode, so you can write a single handler that handles both:

```swift
server.onReceive = { request in
    var req = request
    // Collects the stream (or returns the buffered body immediately)
    let body = try await req.collectBody(maxSize: 10_485_760)  // optional 10 MB cap
    let upload = try body.decode(UploadRequest.self)
    return Response("received \(body.count) bytes")
}
```

After `collectBody()` returns, `request.body` is populated exactly as it would be in buffered mode — form parameters and uploaded files are parsed automatically.

### Iterating chunks directly

When you want zero-copy processing (hashing, forwarding, writing to disk) iterate `request.bodyStream` directly:

```swift
server.onReceive = { request in
    guard let stream = request.bodyStream else {
        // body was small enough to be buffered; access request.body directly
        return Response(request.body.string)
    }

    var totalBytes = 0
    for try await chunk in stream {
        totalBytes += chunk.readableBytes
        // process or forward chunk here without buffering it all
    }
    return Response("received \(totalBytes) bytes")
}
```

### Error handling

`BodyStreamError.tooLarge` is thrown when the `maxSize` limit passed to `collectBody(maxSize:)` or `BodyStream.collect(maxSize:)` is exceeded. If the TCP connection drops mid-stream the sequence throws `ChannelError.ioOnClosedChannel` so a waiting `for try await` loop always terminates.

```swift
do {
    let body = try await req.collectBody(maxSize: 5_242_880)  // 5 MB
} catch BodyStreamError.tooLarge {
    return Response("Payload too large", status: .payloadTooLarge)
}
```

## HTTP/2 Server Push

On HTTP/2 connections you can proactively push resources to the client before it requests them. Call `request.push(_:for:)` inside `onReceive` (or any middleware) for each resource to push.

```swift
server.onReceive = { request in
    // Push the stylesheet before sending the HTML response.
    let css = Body(string: "body { font-family: sans-serif; }")
    var cssResponse = Response(css)
    cssResponse.headers.set(.init(name: .contentType, value: "text/css"))
    request.push(cssResponse, for: URI("/app.css")!)

    return Response("<html>…</html>")
}
```

Calls to `push(_:for:)` on HTTP/1.x connections are silently ignored — you can use the same handler code for both protocol versions without any branching.

The `PUSH_PROMISE` frame is always sent to the client **before** the main `HEADERS` frame, as required by RFC 7540 §8.2.

## Middleware

Middleware runs in array order before `onReceive`. Call `responder(request)` to continue the chain, or return early to short-circuit it.

```swift
struct LoggingMiddleware: Middleware {
    func handle(request: Request, responder: @escaping Responder) async throws -> Encodable {
        print("→ \(request.method) \(request.uri.path)")
        let result = try await responder(request)
        print("← done")
        return result
    }
}

struct AuthMiddleware: Middleware {
    func handle(request: Request, responder: @escaping Responder) async throws -> Encodable {
        guard request.headers.get(.authorization) != nil else {
            return Response("Unauthorized", status: .unauthorized)
        }
        return try await responder(request)
    }
}

server.middleware = [LoggingMiddleware(), AuthMiddleware()]
```

Middleware can mutate the request before passing it on:

```swift
struct UserMiddleware: Middleware {
    func handle(request: Request, responder: @escaping Responder) async throws -> Encodable {
        var request = request
        request.setAttribute("userId", value: resolveUserId(from: request))
        return try await responder(request)
    }
}
```

## Error Middleware

Error middleware is invoked when `onReceive` or any middleware throws. It also forms a chain; call `responder(request, error)` to pass the error to the next handler.

```swift
struct JSONErrorMiddleware: ErrorMiddleware {
    func handle(
        request: Request,
        error: Error,
        responder: @escaping ErrorResponder
    ) async throws -> Encodable {
        let body = "{\"error\":\"\(error.localizedDescription)\"}"
        var response = Response(body, status: .internalServerError)
        response.headers.set(.init(name: .contentType, value: "application/json"))
        return response
    }
}

server.errorMiddleware = [JSONErrorMiddleware()]
```

If no error middleware handles the error the server returns `500 Internal Server Error` automatically.

## Built-in Middleware

### CORSMiddleware

Adds Cross-Origin Resource Sharing headers and handles `OPTIONS` preflight requests automatically.

```swift
server.middleware = [
    CORSMiddleware(options: .init(
        allowCredentials: true,
        allowedHeaders: ["Authorization", "Content-Type"],
        allowedMethods: [.GET, .POST, .PUT, .DELETE],
        allowedOrigin: .origins(["https://app.example.com"]),
        exposedHeaders: ["X-Request-Id"],
        maxAge: 86400
    ))
]
```

`AllowedOrigin` options:

| Value | Behaviour |
|-------|-----------|
| `.all` | `Access-Control-Allow-Origin: *` |
| `.none` | Empty origin value (blocks all cross-origin requests) |
| `.sameAsOrigin` | Echoes the request `Origin` header back |
| `.origins(["https://example.com"])` | Allows exactly the listed origins |
| `.regex(pattern)` | Allows origins matching the given regex pattern string |

### HTTPMethodOverrideMiddleware

Lets HTML forms (which only support `GET` and `POST`) tunnel other HTTP methods via a `_method` form field or an `X-HTTP-Method-Override` header. The form field takes precedence over the header.

```swift
server.middleware = [HTTPMethodOverrideMiddleware()]
```

```html
<form method="POST" action="/posts/42">
    <input type="hidden" name="_method" value="DELETE">
    <button type="submit">Delete</button>
</form>
```

## WebSocket

Assign a closure to `onUpgrade` to handle WebSocket connections. Setting this property enables WebSocket upgrade support — HTTP/1.1 requests carrying `Upgrade: websocket` are intercepted before reaching `onReceive` and handed off to your closure.

```swift
server.onUpgrade = { request, ws in
    // ws.messages is an AsyncSequence of incoming frames.
    for try await message in ws.messages {
        switch message {
        case .text(let text):
            try await ws.send("echo: \(text)")
        case .binary(let data):
            try await ws.send(data)
        }
    }
}
```

The `WebSocket` actor exposes three write methods:

```swift
try await ws.send("hello") // UTF-8 text frame
try await ws.send(byteBuffer) // binary frame
try await ws.close(code: .normalClosure) // send a close frame (default code)
```

The connection is closed automatically when the handler returns or throws. Ping frames are answered with pong frames automatically; you do not need to handle them yourself.

`onUpgrade` has no effect on HTTP/2 connections — the WebSocket-over-HTTP/2 upgrade (RFC 8441) is not currently supported.

## Unix Domain Sockets

Set `unixSocketPath` on the configuration to bind to a Unix domain socket instead of a TCP host and port. This is useful for local inter-process communication and for containers where a socket file is shared via a volume.

```swift
let config = Server.Configuration(unixSocketPath: "/tmp/myapp.sock")
let server = Server(configuration: config)
```

Any stale socket file left by a previous run is removed automatically before binding. When `unixSocketPath` is set the `host`, `port`, and `tcpNoDelay` options are ignored — TCP-only socket options do not apply to Unix domain sockets.

## HTTPS / TLS

Create a `TLS` value from a certificate chain and a private key, then pass it in the server configuration. ALPN negotiation (`h2` and `http/1.1`) is handled automatically.

```swift
guard let tls = TLS(
    certificateFiles: ["/etc/ssl/certs/server.pem"],  // leaf first, then intermediates
    privateKeyFile: "/etc/ssl/private/server.key",
    encoding: .pem                                     // .pem or .der
) else {
    fatalError("Failed to load TLS certificates")
}

let server = Server(configuration: .init(port: 443, tls: tls))
```

To serve HTTP/1.1 over TLS only (no HTTP/2 upgrade):

```swift
Server.Configuration(port: 443, tls: tls, supportsVersions: [.one])
```

`TLS` returns `nil` when `certificateFiles` is empty, `privateKeyFile` is an empty string, or any certificate file cannot be read or parsed.

## Full Example

```swift
import HTTP

struct TimingMiddleware: Middleware {
    func handle(request: Request, responder: @escaping Responder) async throws -> Encodable {
        let start = Date()
        let result = try await responder(request)
        print("Handled in \(Date().timeIntervalSince(start))s")
        return result
    }
}

struct AppErrorMiddleware: ErrorMiddleware {
    func handle(
        request: Request,
        error: Error,
        responder: @escaping ErrorResponder
    ) async throws -> Encodable {
        Response("Something went wrong: \(error)", status: .internalServerError)
    }
}

var config = Server.Configuration(host: "0.0.0.0", port: 8080, serverName: "MyAPI/1.0")
config.streamingBodyThreshold = 1_048_576  // stream request bodies larger than 1 MB

let server = Server(configuration: config)

server.middleware = [TimingMiddleware(), CORSMiddleware(), HTTPMethodOverrideMiddleware()]
server.errorMiddleware = [AppErrorMiddleware()]

server.onStart = { _ in print("Listening on \(server.configuration.socketAddress)") }
server.onStop = { print("Server stopped") }

server.onReceive = { request in
    switch (request.method, request.uri.path) {
    case (.GET, "/"):
        return Response("Welcome!")
    case (.POST, "/echo"):
        // collectBody() works in both buffered and streaming mode
        var req = request
        let body = try await req.collectBody()
        return Response(body.string)
    case (.POST, "/upload"):
        var req = request
        let body = try await req.collectBody(maxSize: 10_485_760)
        return Response("received \(body.count) bytes")
    case (.GET, "/greet"):
        let name: String = request.uri.getQueryParameter("name") ?? "World"
        return Response("Hello, \(name)!")
    default:
        return Response("Not Found", status: .notFound)
    }
}

try server.start()
```

## License

MIT. See [LICENSE](LICENSE) for details.
