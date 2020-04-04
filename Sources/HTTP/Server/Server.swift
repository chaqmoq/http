import Logging
import NIO

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
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(ServerHandler(server: self))
                }
            }
        let channel = try bootstrap.bind(host: configuration.host, port: configuration.port).wait()
        self.channel = channel
        logger.info("Server has started on: \(channel.localAddress!)")
        try channel.closeFuture.wait()
    }

    public func stop() {
        channel?.flush()
        channel?.close().whenComplete { [weak self] result in
            self?.logger.info("Server has stopped")
        }
    }
}
