import NIO

extension Server {
    public struct Configuration {
        public var identifier: String
        public var host: String
        public var port: Int
        public var scheme: String { tls == nil ? "http" : "https" }
        public var socketAddress: String { "\(scheme)://\(host):\(port)" }
        public var serverName: String?
        public var tls: TLS?
        public var supportsVersions: Set<ProtocolVersion.Major>
        public var supportsPipelining: Bool
        public var numberOfThreads: Int
        public var backlog: Int32
        public var reuseAddress: Bool
        public var tcpNoDelay: Bool
        public var maxMessagesPerRead: UInt
        public var requestDecompression: Decompression
        public var responseCompression: Compression

        public init(
            identifier: String = "dev.chaqmoq.http",
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
            maxMessagesPerRead: UInt = 16,
            requestDecompression: Decompression = .init(),
            responseCompression: Compression = .init()
        ) {
            self.identifier = identifier
            self.host = host
            self.port = port
            self.serverName = serverName
            self.tls = tls
            self.supportsVersions = supportsVersions
            self.supportsPipelining = supportsPipelining
            self.numberOfThreads = numberOfThreads
            self.backlog = backlog
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = tcpNoDelay
            self.maxMessagesPerRead = maxMessagesPerRead
            self.requestDecompression = requestDecompression
            self.responseCompression = responseCompression
        }
    }
}

extension Server.Configuration {
    public struct Compression {
        public var initialByteBufferCapacity: Int
        public var isEnabled: Bool

        public init(initialByteBufferCapacity: Int = 1024, isEnabled: Bool = false) {
            self.initialByteBufferCapacity = initialByteBufferCapacity
            self.isEnabled = isEnabled
        }
    }
}

extension Server.Configuration {
    public struct Decompression {
        public enum Limit {
            case none
            case size(Int)
            case ratio(Int)
        }

        public var limit: Limit
        public var isEnabled: Bool

        public init(limit: Limit = .ratio(10), isEnabled: Bool = false) {
            self.limit = limit
            self.isEnabled = isEnabled
        }
    }
}
