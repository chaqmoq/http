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

                if var tls = configuration.tls {
                    return server.configure(tls: &tls, for: channel).flatMap { _ in
                        return channel.configureHTTP2SecureUpgrade(h2ChannelConfigurator: { channel in
                            return channel.configureHTTP2Pipeline(
                                mode: .server,
                                inboundStreamStateInitializer: { (channel, streamID) in
                                    return server.addHandlers(to: channel, streamID: streamID)
                                }
                            ).map { _ in }
                        }, http1ChannelConfigurator: { channel in
                            return server.addHandlers(to: channel)
                        })
                    }
                } else {
                    return server.addHandlers(to: channel)
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
