import NIO
import NIOSSL

extension Server {
    public struct Configuration {
        public var host: String
        public var port: Int
        public var serverName: String? = nil
        public var tls: TLSConfiguration? = nil
        public var supportsVersions: Set<ProtocolVersion.Major>
        public var numberOfThreads: Int
        public var backlog: Int32
        public var reuseAddress: Bool
        public var tcpNoDelay: Bool
        public var maxMessagesPerRead: UInt

        public init(
            host: String = "127.0.0.1",
            port: Int = 8080,
            serverName: String? = nil,
            tls: TLSConfiguration? = nil,
            supportsVersions: Set<ProtocolVersion.Major> = [.one, .two],
            numberOfThreads: Int = System.coreCount,
            backlog: Int32 = 256,
            reuseAddress: Bool = true,
            tcpNoDelay: Bool = true,
            maxMessagesPerRead: UInt = 16
        ) {
            self.host = host
            self.port = port
            self.serverName = serverName
            self.tls = tls
            self.supportsVersions = supportsVersions
            self.numberOfThreads = numberOfThreads
            self.backlog = backlog
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = tcpNoDelay
            self.maxMessagesPerRead = maxMessagesPerRead
        }
    }
}
