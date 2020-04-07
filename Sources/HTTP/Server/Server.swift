import Logging
import NIO
import NIOHTTP1
import NIOHTTP2
import NIOSSL

public class Server {
    public let configuration: Configuration
    public let logger: Logger

    public var onStart: (() -> Void)?
    public var onStop: (() -> Void)?
    public var onError: ((Error) -> Void)?
    public var onReceive: RequestHandler?

    private var channel: Channel?

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
        logger = Logger(label: "dev.chaqmoq.http")
    }

    public func start() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: configuration.numberOfThreads)
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
        self.channel = channel
        let scheme = configuration.tls == nil ? "http" : "https"
        let address = "\(scheme)://\(configuration.host):\(configuration.port)"
        logger.info("Server has started on: \(address)")
        onStart?()
        try channel.closeFuture.wait()
    }

    public func stop() {
        channel?.flush()
        channel?.close().whenComplete { [weak self] result in
            self?.logger.info("Server has stopped")
            self?.onStop?()
        }
    }
}

extension Server {
    private func initializeChild(channel: Channel) -> EventLoopFuture<Void> {
        if let tls = configuration.tls {
            return configure(tls: tls, for: channel).flatMap { _ in
                return channel.configureHTTP2SecureUpgrade(h2ChannelConfigurator: { channel in
                    return channel.configureHTTP2Pipeline(
                        mode: .server,
                        inboundStreamStateInitializer: { [weak self] (channel, streamID) in
                            guard let server = self else { return channel.close() }
                            return server.addHandlers(to: channel, streamID: streamID)
                        }
                    ).map { _ in }
                }, http1ChannelConfigurator: { [weak self] channel in
                    guard let server = self else { return channel.close() }
                    return server.addHandlers(to: channel)
                })
            }
        }

        return addHandlers(to: channel)
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

    private func addHandlers(to channel: Channel, streamID: HTTP2StreamID? = nil) -> EventLoopFuture<Void> {
        if let streamID = streamID {
            return channel.pipeline.configureHTTPServerPipeline().flatMap { [weak self] in
                guard let server = self else { return channel.close() }
                let handlers: [ChannelHandler] = [
                    HTTP2ToHTTP1ServerCodec(streamID: streamID),
                    HTTPHandler(server: server)
                ]

                return channel.pipeline.addHandlers(handlers).flatMap {
                    return channel.pipeline.addHandler(ErrorHandler(server: server))
                }
            }
        }

        return channel.pipeline.configureHTTPServerPipeline().flatMap { [weak self] in
            guard let server = self else { return channel.close() }
            var handlers: [ChannelHandler] = []

            if server.configuration.supportsPipelining {
                handlers.append(HTTPServerPipelineHandler())
            }

            handlers.append(HTTPHandler(server: server))

            return channel.pipeline.addHandlers(handlers).flatMap {
                return channel.pipeline.addHandler(ErrorHandler(server: server))
            }
        }
    }
}
