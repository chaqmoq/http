import Logging
import NIO
import NIOHTTP1
import NIOHTTP2
import NIOSSL

public class Server {
    public let configuration: Configuration
    public let logger: Logger
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
                let configuration = server.configuration
                let logger = server.logger

                if var tls = configuration.tls {
                    if configuration.supportsVersions.contains(.one) {
                        tls.applicationProtocols.append("http/1.1")
                    }

                    let sslContext: NIOSSLContext
                    let sslHandler: NIOSSLServerHandler

                    do {
                        sslContext = try NIOSSLContext(configuration: tls)
                        sslHandler = try NIOSSLServerHandler(context: sslContext)
                    } catch {
                        logger.error("Failed to configure TLS: \(error)")
                        return channel.close()
                    }

                    return channel.pipeline.addHandler(sslHandler).flatMap { _ in
                        return channel.pipeline.configureHTTPServerPipeline().flatMap {
                            return channel.pipeline.addHandler(ServerHandler(server: server))
                        }
                    }
                } else {
                    return channel.pipeline.configureHTTPServerPipeline().flatMap {
                        return channel.pipeline.addHandler(ServerHandler(server: server))
                    }
                }
            }
        let channel = try bootstrap.bind(host: configuration.host, port: configuration.port).wait()
        self.channel = channel
        let scheme = configuration.tls == nil ? "http" : "https"
        let address = "\(scheme)://\(configuration.host):\(configuration.port)"
        logger.info("Server has started on: \(address)")
        try channel.closeFuture.wait()
    }

    public func stop() {
        channel?.flush()
        channel?.close().whenComplete { [weak self] result in
            self?.logger.info("Server has stopped")
        }
    }
}
