import Logging
import NIO
import NIOHTTP1
import NIOHTTP2
import NIOHTTPCompression
import NIOSSL

public final class Server {
    public let configuration: Configuration
    public let logger: Logger
    public let eventLoopGroup: EventLoopGroup

    public var onStart: ((EventLoop) -> Void)?
    public var onStop: (() -> Void)?
    public var onError: ((Error, EventLoop) -> Void)?
    public var onReceive: ((Request, EventLoop) -> Encodable)?
    public var middleware: [Middleware] = .init()

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
        logger = Logger(label: configuration.identifier)
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: configuration.numberOfThreads)
    }

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

    public func stop() throws {
        try eventLoopGroup.syncShutdownGracefully()
        logger.info("Server has stopped")
        onStop?()
    }
}

extension Server {
    private func initializeChild(channel: Channel) -> EventLoopFuture<Void> {
        channel.pipeline.addHandler(BackPressureHandler()).flatMap { [weak self] in
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

        let sslHandler = NIOSSLServerHandler(context: sslContext)

        return channel.pipeline.addHandler(sslHandler)
    }

    private func addHandlers(to channel: Channel, isHTTP2: Bool = false) -> EventLoopFuture<Void> {
        if isHTTP2 {
            return channel.pipeline.configureHTTPServerPipeline().flatMap { [weak self] in
                guard let server = self else { return channel.close() }
                let handlers: [ChannelHandler] = [
                    HTTP2FramePayloadToHTTP1ServerCodec(),
                    RequestDecoder(),
                    ResponseEncoder(),
                    RequestResponseHandler(server: server)
                ]

                return channel.pipeline.addHandlers(handlers).flatMap {
                    channel.pipeline.addHandler(ErrorHandler(server: server))
                }
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
