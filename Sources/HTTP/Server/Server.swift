import Foundation
import Logging
import NIO

public class Server {
    public let logger: Logger
    public var onReceive: RequestHandler?
    private var channel: Channel?

    public init() {
        logger = Logger(label: "dev.chaqmoq.http")
    }

    public func start(host: String = "::1", port: Int = 8080) throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let option = ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR)
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(option, value: 1)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .childChannelOption(option, value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(ServerHandler(server: self))
                }
            }
        let channel = try bootstrap.bind(host: host, port: port).wait()
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
