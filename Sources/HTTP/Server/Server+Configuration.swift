import NIO

extension Server {
    public struct Configuration {
        public var host: String
        public var port: Int
        public var numberOfThreads: Int
        public var backlog: Int32
        public var reuseAddress: Bool
        public var tcpNoDelay: Bool
        public var maxMessagesPerRead: UInt

        public init(
            host: String = "127.0.0.1",
            port: Int = 8080,
            numberOfThreads: Int = System.coreCount,
            backlog: Int32 = 256,
            reuseAddress: Bool = true,
            tcpNoDelay: Bool = true,
            maxMessagesPerRead: UInt = 16
        ) {
            self.host = host
            self.port = port
            self.numberOfThreads = numberOfThreads
            self.backlog = backlog
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = tcpNoDelay
            self.maxMessagesPerRead = maxMessagesPerRead
        }
    }
}
