import Logging
import NIO
import NIOConcurrencyHelpers
import NIOHTTP1
import NIOHTTP2
import NIOHTTPCompression
import NIOSSL
import NIOWebSocket

/// A non-blocking HTTP/1.1 and HTTP/2 server powered by SwiftNIO.
///
/// `Server` manages the full lifecycle of an HTTP server: binding to a socket, accepting
/// connections, decoding requests, running middleware, dispatching to the application
/// handler, encoding responses, and optionally terminating TLS.
///
/// ## Basic Usage
///
/// ```swift
/// let server = Server()
/// server.onReceive = { request in
///     Response("Hello, World!")
/// }
/// try server.start() // Blocks until the server is stopped.
/// ```
///
/// ## Middleware
///
/// Register middleware by appending to `middleware` or `errorMiddleware` before calling
/// `start()`. Middleware is executed in array order for every request.
///
/// ```swift
/// server.middleware = [CORSMiddleware(), HTTPMethodOverrideMiddleware()]
/// ```
public final class Server: @unchecked Sendable {
    /// The server configuration snapshot provided at initialisation.
    public let configuration: Configuration

    /// A structured logger scoped to this server instance.
    public let logger: Logger

    /// The NIO event-loop group driving I/O for this server.
    public let eventLoopGroup: EventLoopGroup

    // All mutable properties are guarded by this lock so that reads from NIO
    // event-loop threads and writes from any other thread are race-free.
    private let lock = NIOLock()

    private var _onStart: ((EventLoop) -> Void)?
    /// Called on the first event loop when the server has successfully bound its socket.
    public var onStart: ((EventLoop) -> Void)? {
        get { lock.withLock { _onStart } }
        set { lock.withLock { _onStart = newValue } }
    }

    private var _onStop: (() -> Void)?
    /// Called after the event-loop group has been shut down gracefully.
    public var onStop: (() -> Void)? {
        get { lock.withLock { _onStop } }
        set { lock.withLock { _onStop = newValue } }
    }

    private var _onError: ((Error, EventLoop) -> Void)?
    /// Called when an unrecoverable channel-level error occurs.
    public var onError: ((Error, EventLoop) -> Void)? {
        get { lock.withLock { _onError } }
        set { lock.withLock { _onError = newValue } }
    }

    private var _onReceive: ((Request) async throws -> Encodable)?
    /// The application handler invoked for every incoming request after all middleware runs.
    ///
    /// Return any `Encodable` value; if it is not a `Response` it will be wrapped in one
    /// using its string description.
    public var onReceive: ((Request) async throws -> Encodable)? {
        get { lock.withLock { _onReceive } }
        set { lock.withLock { _onReceive = newValue } }
    }

    private var _onUpgrade: ((Request, WebSocket) async throws -> Void)?
    /// Called when an HTTP/1.1 connection is upgraded to WebSocket.
    ///
    /// Receives the original upgrade `Request` and a live ``WebSocket`` object. Send frames
    /// via ``WebSocket/send(_:)-text`` / ``WebSocket/send(_:)-binary`` and receive them by
    /// iterating ``WebSocket/messages``. The connection is closed automatically when the
    /// handler returns or throws.
    ///
    /// Setting this to a non-`nil` value enables WebSocket upgrade support on the server.
    /// HTTP/1.1 connections that carry an `Upgrade: websocket` header are intercepted before
    /// reaching ``onReceive``.
    ///
    /// ```swift
    /// server.onUpgrade = { request, ws in
    ///     for try await message in ws.messages {
    ///         if case .text(let text) = message {
    ///             try await ws.send("echo: \(text)")
    ///         }
    ///     }
    /// }
    /// ```
    public var onUpgrade: ((Request, WebSocket) async throws -> Void)? {
        get { lock.withLock { _onUpgrade } }
        set { lock.withLock { _onUpgrade = newValue } }
    }

    private var _middleware = [Middleware]()
    /// Middleware executed in order for each request before ``onReceive`` is called.
    public var middleware: [Middleware] {
        get { lock.withLock { _middleware } }
        set { lock.withLock { _middleware = newValue } }
    }

    private var _errorMiddleware = [ErrorMiddleware]()
    /// Error middleware executed when a request handler or middleware throws.
    public var errorMiddleware: [ErrorMiddleware] {
        get { lock.withLock { _errorMiddleware } }
        set { lock.withLock { _errorMiddleware = newValue } }
    }

    // Built once in start() from the TLS configuration and reused for every accepted
    // connection. NIOSSLContext wraps an SSL_CTX and is safe to share across threads.
    private var _sslContext: NIOSSLContext?
    private var sslContext: NIOSSLContext? {
        get { lock.withLock { _sslContext } }
        set { lock.withLock { _sslContext = newValue } }
    }

    /// Initializes a new `Server` with the given configuration.
    ///
    /// - Parameter configuration: The server configuration. Defaults to ``Configuration/init()``.
    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
        logger = Logger(label: configuration.identifier)
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: configuration.numberOfThreads)
    }

    /// Binds the socket and starts accepting connections.
    ///
    /// This method **blocks the calling thread** until ``stop()`` is called or the
    /// channel's close future completes. Run it on a dedicated thread or background queue.
    ///
    /// - Throws: An error if the socket cannot be bound.
    public func start() throws {
        // Build the NIOSSLContext once so it is shared across all accepted connections.
        // Creating it per-connection would re-allocate an SSL_CTX on every accept, which
        // is expensive. NIOSSLContext is thread-safe and designed for shared use.
        if let tls = configuration.tls {
            var tlsConfiguration = tls.configuration

            if configuration.supportsVersions.contains(.two) {
                tlsConfiguration.applicationProtocols.append("h2")
            }

            if configuration.supportsVersions.contains(.one) {
                tlsConfiguration.applicationProtocols.append("http/1.1")
            }

            do {
                sslContext = try NIOSSLContext(configuration: tlsConfiguration)
            } catch {
                logger.error("Failed to configure TLS: \(error)")
                throw error
            }
        }

        let reuseAddressOption = ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR)
        let reuseAddressOptionValue = SocketOptionValue(configuration.reuseAddress ? 1 : 0)
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: configuration.backlog)
            .serverChannelOption(reuseAddressOption, value: reuseAddressOptionValue)
            .childChannelOption(reuseAddressOption, value: reuseAddressOptionValue)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: configuration.maxMessagesPerRead)
            .childChannelInitializer { [weak self] channel in
                guard let server = self else { return channel.close() }
                return server.initializeChild(channel: channel)
            }

        // TCP_NODELAY (Nagle's algorithm) is a TCP-only option — applying it to a
        // Unix domain socket would fail with ENOPROTOOPT and close every accepted channel.
        if configuration.unixSocketPath == nil {
            _ = bootstrap.childChannelOption(
                ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY),
                value: SocketOptionValue(configuration.tcpNoDelay ? 1 : 0)
            )
        }

        let channel: Channel
        if let unixSocketPath = configuration.unixSocketPath {
            // Remove any stale socket file left by a previous run so that bind succeeds.
            channel = try bootstrap.bind(unixDomainSocketPath: unixSocketPath, cleanupExistingSocketFile: true).wait()
            logger.info("Server has started on unix:\(unixSocketPath)")
        } else {
            channel = try bootstrap.bind(host: configuration.host, port: configuration.port).wait()
            logger.info("Server has started on: \(configuration.socketAddress)")
        }

        // Snapshot the closure outside the lock before invoking it.
        let onStart = self.onStart
        onStart?(channel.eventLoop)
        try channel.closeFuture.wait()
    }

    /// Shuts down the event-loop group gracefully and stops the server.
    ///
    /// - Throws: An error if the event-loop group cannot be shut down.
    public func stop() throws {
        try eventLoopGroup.syncShutdownGracefully()
        logger.info("Server has stopped")
        // Snapshot the closure outside the lock before invoking it.
        let onStop = self.onStop
        onStop?()
    }
}

extension Server {
    private func initializeChild(channel: Channel) -> EventLoopFuture<Void> {
        // Cast to ChannelHandler to select the non-Sendable overload; BackPressureHandler is
        // intentionally not Sendable (it is always used on its event loop).
        let backPressureHandler: ChannelHandler = BackPressureHandler()
        return channel.pipeline.addHandler(backPressureHandler).flatMap { [weak self] in
            guard let server = self else { return channel.close() }

            if server.configuration.tls != nil {
                return server.configureSSL(for: channel).flatMap { _ in
                    channel.configureHTTP2SecureUpgrade(h2ChannelConfigurator: { channel in
                        channel.configureHTTP2Pipeline(mode: .server) { channel in
                            server.addHandlers(to: channel, isHTTP2: true)
                        }.map { _ in }
                    }, http1ChannelConfigurator: { channel in
                        server.addHandlers(to: channel)
                    })
                }
            }

            return server.addHandlers(to: channel)
        }
    }

    private func configureSSL(for channel: Channel) -> EventLoopFuture<Void> {
        guard let sslContext else {
            logger.error("SSL context not initialised — configureSSL called before start()")
            return channel.close()
        }

        // Cast to ChannelHandler to select the non-Sendable overload; NIOSSLServerHandler is
        // intentionally not Sendable (it is always used on its event loop).
        let sslHandler: ChannelHandler = NIOSSLServerHandler(context: sslContext)

        return channel.pipeline.addHandler(sslHandler)
    }

    private func addHandlers(to channel: Channel, isHTTP2: Bool = false) -> EventLoopFuture<Void> {
        if isHTTP2 {
            // HTTP/2 stream channels deliver HTTP2Frame.FramePayload objects, not raw bytes.
            // configureHTTPServerPipeline() is for HTTP/1 only and must NOT be called here;
            // HTTP2FramePayloadToHTTP1ServerCodec bridges h2 frames to HTTP/1-style messages.
            //
            // HTTP2PushHandler sits at the network-facing end (position 1) so that it
            // receives HTTP2Frame.FramePayload outbound (after the codec converts the response)
            // and can inject PUSH_PROMISE frames directly into the stream channel's write
            // mechanism without going back through the codec.
            let pushHandler = HTTP2PushHandler()
            let handlers: [ChannelHandler] = [
                pushHandler,
                HTTP2FramePayloadToHTTP1ServerCodec(),
                RequestDecoder(
                    maxBodySize: configuration.maxBodySize,
                    streamingBodyThreshold: configuration.streamingBodyThreshold
                ),
                ResponseEncoder(),
                RequestResponseHandler(server: self, pushHandler: pushHandler)
            ]

            return channel.pipeline.addHandlers(handlers).flatMap { [weak self] in
                guard let server = self else { return channel.close() }
                return channel.pipeline.addHandler(ErrorHandler(server: server))
            }
        }

        // Build the WebSocket upgrader when onUpgrade is configured.
        // The upgrader is wired into configureHTTPServerPipeline so that NIO's
        // HTTPServerUpgradeHandler intercepts Upgrade: websocket requests before
        // they reach RequestDecoder.
        let upgradeConfig: NIOHTTPServerUpgradeConfiguration? = self.onUpgrade.map { onUpgradeHandler in
            let upgrader = NIOWebSocketServerUpgrader(
                shouldUpgrade: { channel, _ in
                    // Accept every WebSocket upgrade unconditionally.
                    channel.eventLoop.makeSucceededFuture(HTTPHeaders())
                },
                upgradePipelineHandler: { [weak self] channel, head in
                    // Reconstruct a partial Request from the HTTP upgrade head so the
                    // application handler can inspect headers, path, etc.
                    let method  = Request.Method(rawValue: head.method.rawValue) ?? .GET
                    let uri     = URI(head.uri) ?? .default
                    let version = Version(major: head.version.major, minor: head.version.minor)
                    var headers = Headers()
                    for h in head.headers { headers.set(.init(name: h.name, value: h.value)) }
                    let request = Request(
                        eventLoop: channel.eventLoop,
                        method: method, uri: uri, version: version, headers: headers
                    )
                    let ws = WebSocket(request: request, channel: channel)
                    // Kick off the application handler in a Swift concurrency Task.
                    // Errors are forwarded to onError (if configured).
                    Task { [weak self] in
                        do {
                            try await onUpgradeHandler(request, ws)
                        } catch {
                            self?.onError?(error, channel.eventLoop)
                        }
                    }
                    // Add the frame ↔ WebSocket bridge after the NIO WebSocket codecs.
                    return channel.pipeline.addHandler(WebSocketHandler(webSocket: ws))
                }
            )

            return (
                upgraders: [upgrader],
                // completionHandler runs after the upgrade is complete (101 sent,
                // HTTP codec removed). Remove the HTTP application handlers so that
                // raw WebSocket frames do not flow through RequestDecoder.
                completionHandler: { ctx in
                    let pipeline = ctx.pipeline
                    // Each removal is a no-op (.recover) if the handler was never added
                    // (e.g. compression was disabled).
                    func removeIfPresent<H: ChannelHandler>(_ type: H.Type) {
                        _ = pipeline.context(handlerType: type)
                            .flatMap { pipeline.syncOperations.removeHandler(context: $0) }
                            .recover { _ in }
                    }
                    removeIfPresent(HTTPServerPipelineHandler.self)
                    removeIfPresent(HTTPResponseCompressor.self)
                    removeIfPresent(NIOHTTPRequestDecompressor.self)
                    removeIfPresent(RequestDecoder.self)
                    removeIfPresent(ResponseEncoder.self)
                    removeIfPresent(RequestResponseHandler.self)
                    removeIfPresent(ErrorHandler.self)
                }
            )
        }

        return channel.pipeline.configureHTTPServerPipeline(withServerUpgrade: upgradeConfig).flatMap { [weak self] in
            guard let server = self else { return channel.close() }
            var handlers = [ChannelHandler]()

            if server.configuration.supportsPipelining {
                handlers.append(HTTPServerPipelineHandler())
            }

            if server.configuration.responseCompression.isEnabled {
                let initialByteBufferCapacity = server.configuration.responseCompression.initialByteBufferCapacity
                handlers.append(HTTPResponseCompressor(initialByteBufferCapacity: initialByteBufferCapacity))
            }

            if server.configuration.requestDecompression.isEnabled {
                let limit = server.configuration.requestDecompression.limit
                let decompressionLimit: NIOHTTPDecompression.DecompressionLimit

                switch limit {
                case .none:
                    decompressionLimit = .none
                case let .size(size):
                    decompressionLimit = .size(size)
                case let .ratio(ratio):
                    decompressionLimit = .ratio(ratio)
                }

                handlers.append(NIOHTTPRequestDecompressor(limit: decompressionLimit))
            }

            let otherHandlers: [ChannelHandler] = [
                RequestDecoder(
                    maxBodySize: server.configuration.maxBodySize,
                    streamingBodyThreshold: server.configuration.streamingBodyThreshold
                ),
                ResponseEncoder(),
                RequestResponseHandler(server: server),
            ]
            handlers.append(contentsOf: otherHandlers)

            return channel.pipeline.addHandlers(handlers).flatMap {
                channel.pipeline.addHandler(ErrorHandler(server: server))
            }
        }
    }
}
