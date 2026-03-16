import NIO
import NIOWebSocket

/// An active WebSocket connection handed to ``Server/onUpgrade``.
///
/// Use ``messages`` to receive incoming frames and ``send(_:)-text`` / ``send(_:)-binary``
/// to write outbound frames. The connection is closed when the remote peer sends a close
/// frame, when ``close(code:)`` is called, or when the upgrade handler returns or throws.
///
/// ```swift
/// server.onUpgrade = { request, ws in
///     for try await message in ws.messages {
///         switch message {
///         case .text(let text):   try await ws.send("echo: \(text)")
///         case .binary(let data): try await ws.send(data)
///         }
///     }
/// }
/// ```
public actor WebSocket: Sendable {

    // MARK: - Message

    /// A single message received from the remote peer.
    public enum Message: Sendable {
        /// A UTF-8 text frame.
        case text(String)
        /// A binary data frame.
        case binary(ByteBuffer)
    }

    // MARK: - Properties

    /// The HTTP upgrade request that opened this connection.
    public let request: Request

    /// An `AsyncStream` of messages received from the remote peer.
    ///
    /// The stream terminates (yields `nil`) when the connection is closed from either side.
    public let messages: AsyncStream<Message>

    // Channel reference held for writing outbound frames.
    // Access is always from the actor's executor or from nonisolated helpers, so
    // @unchecked Sendable is not needed — Channel itself is `@unchecked Sendable`.
    let channel: Channel

    private let continuation: AsyncStream<Message>.Continuation

    // MARK: - Init

    init(request: Request, channel: Channel) {
        self.request = request
        self.channel = channel
        var cont: AsyncStream<Message>.Continuation!
        messages = AsyncStream { cont = $0 }
        continuation = cont
    }

    // MARK: - Sending

    /// Sends a UTF-8 text frame to the remote peer.
    ///
    /// - Throws: Any network error reported by the underlying NIO channel.
    public func send(_ text: String) async throws {
        var buffer = channel.allocator.buffer(capacity: text.utf8.count)
        buffer.writeString(text)
        let frame = WebSocketFrame(fin: true, opcode: .text, data: buffer)
        try await channel.writeAndFlush(frame).get()
    }

    /// Sends a binary frame to the remote peer.
    ///
    /// - Throws: Any network error reported by the underlying NIO channel.
    public func send(_ data: ByteBuffer) async throws {
        let frame = WebSocketFrame(fin: true, opcode: .binary, data: data)
        try await channel.writeAndFlush(frame).get()
    }

    /// Sends a WebSocket close frame and closes the channel.
    ///
    /// - Parameter code: The WebSocket close status code. Defaults to `.normalClosure`.
    /// - Throws: Any network error reported by the underlying NIO channel.
    public func close(code: WebSocketErrorCode = .normalClosure) async throws {
        var buffer = channel.allocator.buffer(capacity: 2)
        buffer.write(webSocketErrorCode: code)
        let frame = WebSocketFrame(fin: true, opcode: .connectionClose, data: buffer)
        try await channel.writeAndFlush(frame).get()
    }

    // MARK: - Internal (called by WebSocketHandler on the channel's event loop)

    /// Delivers a received message to the async stream.
    nonisolated func yield(_ message: Message) {
        continuation.yield(message)
    }

    /// Signals end-of-stream — called when the channel becomes inactive.
    nonisolated func finish() {
        continuation.finish()
    }
}
