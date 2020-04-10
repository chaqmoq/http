import NIO
import NIOSSL

extension Server {
    public struct Configuration {
        public var scheme: String { tls == nil ? "http" : "https" }
        public var socketAddress: String { "\(scheme)://\(host):\(port)" }
        public var host: String
        public var port: Int
        public var serverName: String? = nil
        public var tls: TLS? = nil { didSet { port = tls == nil ? 8080 : 8443 } }
        public var supportsVersions: Set<ProtocolVersion.Major>
        public var supportsPipelining: Bool
        public var numberOfThreads: Int
        public var backlog: Int32
        public var reuseAddress: Bool
        public var tcpNoDelay: Bool
        public var maxMessagesPerRead: UInt

        public init(
            host: String = "127.0.0.1",
            port: Int = 8080,
            serverName: String? = nil,
            tls: TLS? = nil,
            supportsVersions: Set<ProtocolVersion.Major> = [.one, .two],
            supportsPipelining: Bool = false,
            numberOfThreads: Int = System.coreCount,
            backlog: Int32 = 256,
            reuseAddress: Bool = true,
            tcpNoDelay: Bool = true,
            maxMessagesPerRead: UInt = 16
        ) {
            self.host = host
            self.port = tls == nil ? port : 8443
            self.serverName = serverName
            self.tls = tls
            self.supportsVersions = supportsVersions
            self.supportsPipelining = supportsPipelining
            self.numberOfThreads = numberOfThreads
            self.backlog = backlog
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = tcpNoDelay
            self.maxMessagesPerRead = maxMessagesPerRead
        }
    }
}
