import Logging
@preconcurrency import NIO
@preconcurrency import NIOHTTP1
@preconcurrency import NIOHTTP2
@preconcurrency import NIOHTTPCompression
@preconcurrency import NIOSSL

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

    /// Called on the first event loop when the server has successfully bound its socket.
    public var onStart: ((EventLoop) -> Void)?

    /// Called after the event-loop group has been shut down gracefully.
    public var onStop: (() -> Void)?

    /// Called when an unrecoverable channel-level error occurs.
    public var onError: ((Error, EventLoop) -> Void)?

    /// The application handler invoked for every incoming request after all middleware runs.
    ///
    /// Return any `Encodable` value; if it is not a `Response` it will be wrapped in one
    /// using its string description.
    public var onReceive: ((Request) async throws -> Encodable)?

    /// Middleware executed in order for each request before ``onReceive`` is called.
    public var middleware = [Middleware]()

    /// Error middleware executed when a request handler or middleware throws.
    public var errorMiddleware = [ErrorMiddleware]()

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
        let reuseAddressOption = ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR)
        let reuseAddressOptionValue = SocketOptionValue(configuration.reuseAddress ? 1 : 0)
        let tcpNoDelayOptionValue = SocketOptionValue(configuration.tcpNoDelay ? 1 : 0)
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: configuration.backlog)
            .serverChannelOption(reuseAddressOption, value: reuseAddressOptionValue)
            .childChannelOption(reuseAddressOption, value: reuseAddressOptionValue)
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: tcpNoDelayOptionValue)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: configuration.maxMessagesPerRead)
            .childChannelInitializer { [weak self] channel in
                guard let server = self else { return channel.close() }
                return server.initializeChild(channel: channel)
            }

        let channel = try bootstrap.bind(host: configuration.host, port: configuration.port).wait()
        logger.info("Server has started on: \(configuration.socketAddress)")
        onStart?(channel.eventLoop)
        try channel.closeFuture.wait()
    }

    /// Shuts down the event-loop group gracefully and stops the server.
    ///
    /// - Throws: An error if the event-loop group cannot be shut down.
    public func stop() throws {
        try eventLoopGroup.syncShutdownGracefully()
        logger.info("Server has stopped")
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

            if let tls = server.configuration.tls {
                return server.configure(tls: tls, for: channel).flatMap { _ in
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

    private func configure(tls: TLS, for channel: Channel) -> EventLoopFuture<Void> {
        var tlsConfiguration = tls.configuration

        if configuration.supportsVersions.contains(.two) {
            tlsConfiguration.applicationProtocols.append("h2")
        }

        if configuration.supportsVersions.contains(.one) {
            tlsConfiguration.applicationProtocols.append("http/1.1")
        }

        let sslContext: NIOSSLContext

        do {
            sslContext = try NIOSSLContext(configuration: tlsConfiguration)
        } catch {
            logger.error("Failed to configure TLS: \(error)")
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
            let handlers: [ChannelHandler] = [
                HTTP2FramePayloadToHTTP1ServerCodec(),
                RequestDecoder(),
                ResponseEncoder(),
                RequestResponseHandler(server: self)
            ]

            return channel.pipeline.addHandlers(handlers).flatMap { [weak self] in
                guard let server = self else { return channel.close() }

                return channel.pipeline.addHandler(ErrorHandler(server: server))
            }
        }

        return channel.pipeline.configureHTTPServerPipeline().flatMap { [weak self] in
            guard let server = self else { return channel.close() }
            var handlers: [ChannelHandler] = []

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
                RequestDecoder(),
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
