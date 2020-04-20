import struct Logging.Logger
import NIO
import NIOHTTP1
import NIOHTTP2
import NIOHTTPCompression
import NIOSSL

public class Server {
    public let configuration: Configuration
    public let logger: Logger
    var eventLoopGroup: EventLoopGroup?

    public var onStart: ((EventLoop) -> Void)?
    public var onStop: (() -> Void)?
    public var onError: ((Error, EventLoop) -> Void)?
    public var onReceive: ((Request, EventLoop) -> Any)?

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
        logger = Logger(label: configuration.identifier)
    }

    public func start() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: configuration.numberOfThreads)
        eventLoopGroup = group
        let reuseAddressOption = ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR)
        let reuseAddressOptionValue = SocketOptionValue(configuration.reuseAddress ? 1 : 0)
        let tcpNoDelayOptionValue = SocketOptionValue(configuration.tcpNoDelay ? 1 : 0)
        let bootstrap = ServerBootstrap(group: group)
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
        try eventLoopGroup?.syncShutdownGracefully()
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
                        channel.configureHTTP2Pipeline(
                            mode: .server,
                            inboundStreamStateInitializer: { (channel, streamID) in
                                server.addHandlers(to: channel, with: streamID)
                            }
                        ).map { _ in }
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
        let sslHandler: NIOSSLServerHandler

        do {
            sslContext = try NIOSSLContext(configuration: tlsConfiguration)
            sslHandler = try NIOSSLServerHandler(context: sslContext)
        } catch {
            logger.error("Failed to configure TLS: \(error)")
            return channel.close()
        }

        return channel.pipeline.addHandler(sslHandler)
    }

    private func addHandlers(to channel: Channel, with streamID: HTTP2StreamID? = nil) -> EventLoopFuture<Void> {
        if let streamID = streamID {
            return channel.pipeline.configureHTTPServerPipeline().flatMap { [weak self] in
                guard let server = self else { return channel.close() }
                let handlers: [ChannelHandler] = [
                    HTTP2ToHTTP1ServerCodec(streamID: streamID),
                    RequestDecoder(server: server),
                    ResponseEncoder(server: server),
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
                case .size(let size):
                    decompressionLimit = .size(size)
                case .ratio(let ratio):
                    decompressionLimit = .ratio(ratio)
                }

                handlers.append(NIOHTTPRequestDecompressor(limit: decompressionLimit))
            }

            let otherHandlers: [ChannelHandler] = [
                RequestDecoder(server: server),
                ResponseEncoder(server: server),
                RequestResponseHandler(server: server)
            ]
            handlers.append(contentsOf: otherHandlers)

            return channel.pipeline.addHandlers(handlers).flatMap {
                channel.pipeline.addHandler(ErrorHandler(server: server))
            }
        }
    }
}
