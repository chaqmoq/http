import NIO

extension Server {
    /// Immutable configuration snapshot used to initialise a ``Server``.
    ///
    /// All properties have sensible defaults so that a development server can be started
    /// with `Server()` without any additional setup.
    public struct Configuration: Equatable {
        /// A reverse-DNS identifier used as the logger label (e.g. `"dev.chaqmoq.http"`).
        public var identifier: String

        /// The host address to bind to. Defaults to `"127.0.0.1"`.
        public var host: String

        /// The port to listen on. Defaults to `8080`.
        public var port: Int

        /// Returns `"https"` when TLS is configured, otherwise `"http"`.
        public var scheme: String { tls == nil ? "http" : "https" }

        /// The full socket address string, e.g. `"http://127.0.0.1:8080"`.
        public var socketAddress: String { "\(scheme)://\(host):\(port)" }

        /// The value to set in the `Server` response header. `nil` omits the header.
        public var serverName: String?

        /// Optional TLS configuration. When non-`nil` the server will handle HTTPS.
        public var tls: TLS?

        /// File-system path for a Unix domain socket to bind instead of a TCP host/port.
        ///
        /// When non-`nil` the server binds to this path and ignores ``host`` and ``port``.
        /// Any stale socket file at the path is removed before binding.
        ///
        /// Unix domain sockets are useful for local inter-process communication — for example
        /// when the server runs behind a reverse proxy (nginx, Caddy) on the same machine.
        ///
        /// ```swift
        /// var config = Server.Configuration()
        /// config.unixSocketPath = "/tmp/myapp.sock"
        /// ```
        public var unixSocketPath: String?

        /// The set of HTTP major versions the server accepts. Defaults to `[.one, .two]`.
        public var supportsVersions: Set<Version.Major>

        /// Whether HTTP pipelining is enabled for HTTP/1.x connections. Defaults to `false`.
        public var supportsPipelining: Bool

        /// The number of NIO event-loop threads. Defaults to `System.coreCount`.
        public var numberOfThreads: Int

        /// The TCP backlog for the listening socket. Defaults to `256`.
        public var backlog: Int32

        /// Whether `SO_REUSEADDR` is enabled. Defaults to `true`.
        public var reuseAddress: Bool

        /// Whether `TCP_NODELAY` is enabled (disables Nagle's algorithm). Defaults to `true`.
        public var tcpNoDelay: Bool

        /// The maximum number of messages read per event-loop cycle. Defaults to `16`.
        public var maxMessagesPerRead: UInt

        /// Maximum allowed size of a request body in bytes. `nil` means no limit.
        ///
        /// When set, any request whose accumulated body exceeds this value is rejected
        /// with a `RequestDecoder.Error.bodyTooLarge` channel error and the connection
        /// is closed. Applies to the decompressed body size.
        ///
        /// Defaults to `nil` (unlimited). Consider setting a sensible limit for
        /// production deployments to guard against memory exhaustion.
        public var maxBodySize: Int?

        /// Body size threshold (in bytes) that switches ``RequestDecoder`` into
        /// streaming mode for large request bodies.
        ///
        /// When non-`nil`:
        /// - Bodies with a known `Content-Length` **greater than** this value are
        ///   delivered as a ``BodyStream`` on ``Request/bodyStream``. The handler
        ///   receives the request immediately and consumes the body lazily via
        ///   ``Request/collectBody(maxSize:)`` or direct async iteration.
        /// - Bodies with an **unknown** length (chunked transfer encoding or no
        ///   `Content-Length` header) are also streamed.
        /// - Bodies at or below the threshold continue to be fully buffered, so
        ///   ``Request/body`` is populated as normal.
        ///
        /// When `nil` (the default), all bodies are fully buffered before the handler
        /// is invoked — preserving backward compatibility.
        ///
        /// ## Example
        /// ```swift
        /// // Buffer bodies up to 1 MB; stream everything larger.
        /// var config = Server.Configuration()
        /// config.streamingBodyThreshold = 1_048_576
        /// let server = Server(configuration: config)
        ///
        /// server.onReceive = { request in
        ///     var req = request
        ///     let body = try await req.collectBody(maxSize: 10_485_760) // 10 MB hard cap
        ///     return Response("received \(body.count) bytes")
        /// }
        /// ```
        public var streamingBodyThreshold: Int?

        /// Request body decompression settings.
        public var requestDecompression: Decompression

        /// Response body compression settings.
        public var responseCompression: Compression

        public init(
            identifier: String = "dev.chaqmoq.http",
            host: String = "127.0.0.1",
            port: Int = 8080,
            serverName: String? = nil,
            tls: TLS? = nil,
            unixSocketPath: String? = nil,
            supportsVersions: Set<Version.Major> = [.one, .two],
            supportsPipelining: Bool = false,
            numberOfThreads: Int = System.coreCount,
            backlog: Int32 = 256,
            reuseAddress: Bool = true,
            tcpNoDelay: Bool = true,
            maxMessagesPerRead: UInt = 16,
            maxBodySize: Int? = nil,
            streamingBodyThreshold: Int? = nil,
            requestDecompression: Decompression = .init(),
            responseCompression: Compression = .init()
        ) {
            self.identifier = identifier
            self.host = host
            self.port = port
            self.serverName = serverName
            self.tls = tls
            self.unixSocketPath = unixSocketPath
            self.supportsVersions = supportsVersions
            self.supportsPipelining = supportsPipelining
            self.numberOfThreads = numberOfThreads
            self.backlog = backlog
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = tcpNoDelay
            self.maxMessagesPerRead = maxMessagesPerRead
            self.maxBodySize = maxBodySize
            self.streamingBodyThreshold = streamingBodyThreshold
            self.requestDecompression = requestDecompression
            self.responseCompression = responseCompression
        }
    }
}

extension Server.Configuration {
    /// Settings for HTTP response body compression (gzip/deflate).
    public struct Compression: Equatable {
        /// The initial capacity (in bytes) of the compressor's byte buffer. Defaults to `1024`.
        public var initialByteBufferCapacity: Int

        /// Whether response compression is active. Defaults to `true`.
        public var isEnabled: Bool

        /// Initializes compression settings.
        ///
        /// - Parameters:
        ///   - initialByteBufferCapacity: The initial buffer size in bytes. Defaults to `1024`.
        ///   - isEnabled: Whether compression is enabled. Defaults to `true`.
        public init(initialByteBufferCapacity: Int = 1024, isEnabled: Bool = true) {
            self.initialByteBufferCapacity = initialByteBufferCapacity
            self.isEnabled = isEnabled
        }
    }
}

extension Server.Configuration {
    /// Settings for HTTP request body decompression (gzip/deflate).
    public struct Decompression: Equatable {
        /// Controls the maximum allowed inflation ratio or size to guard against
        /// decompression bombs.
        public enum Limit: Equatable {
            /// No limit on decompressed size.
            case none
            /// Maximum decompressed size in bytes.
            case size(Int)
            /// Maximum ratio of decompressed-to-compressed size.
            case ratio(Int)
        }

        /// The decompression limit. Defaults to `.ratio(10)`.
        public var limit: Limit

        /// Whether request decompression is active. Defaults to `true`.
        public var isEnabled: Bool

        /// Initializes decompression settings.
        ///
        /// - Parameters:
        ///   - limit: The decompression limit. Defaults to `.ratio(10)`.
        ///   - isEnabled: Whether decompression is enabled. Defaults to `true`.
        public init(limit: Limit = .ratio(10), isEnabled: Bool = true) {
            self.limit = limit
            self.isEnabled = isEnabled
        }
    }
}
