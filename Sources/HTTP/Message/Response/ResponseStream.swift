import Foundation
import NIO

/// A response body that is produced incrementally rather than held in memory up front.
///
/// Use it for long-lived responses such as Server-Sent Events, or for large payloads that are
/// generated on the fly. The server writes the response head as soon as the handler returns, then
/// runs the producer; every ``ResponseStreamWriter/write(_:)-(ByteBuffer)`` is flushed to the client
/// immediately. The response ends when the producer returns.
///
/// ```swift
/// server.onReceive = { request in
///     Response(stream: .init { writer in
///         for tick in 1...3 {
///             try await writer.write("data: \(tick)\n\n")
///             try await Task.sleep(for: .seconds(1))
///         }
///     }, headers: .init((.contentType, "text/event-stream")))
/// }
/// ```
///
/// - A streamed response never carries `Content-Length`. HTTP/1.1 uses chunked transfer encoding,
///   HTTP/1.0 is delimited by closing the connection, and HTTP/2 ends the stream with END_STREAM.
/// - When the client goes away the producer's task is **cancelled**, and any further `write`
///   throws. Producers that wait on external events should therefore honour cancellation.
/// - An error thrown by the producer ends the response. The status and headers have already been
///   sent at that point, so it cannot be turned into an error response.
public struct ResponseStream: Sendable {
    /// The closure that produces the body.
    public typealias Producer = @Sendable (ResponseStreamWriter) async throws -> Void

    let producer: Producer

    /// Creates a streamed body.
    ///
    /// - Parameter producer: Writes the body through the supplied writer and returns when done.
    public init(_ producer: @escaping Producer) {
        self.producer = producer
    }
}

extension ResponseStream: Encodable {
    /// A stream has no static representation; it encodes as `nil`.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}

/// Writes chunks of a ``ResponseStream`` to the client.
///
/// Each write is flushed and suspends until the bytes have been handed to the channel, which gives
/// the producer natural back-pressure. A write on a connection that has closed throws.
public struct ResponseStreamWriter: Sendable {
    private let writeBuffer: @Sendable (ByteBuffer) async throws -> Void

    init(_ writeBuffer: @escaping @Sendable (ByteBuffer) async throws -> Void) {
        self.writeBuffer = writeBuffer
    }

    /// Writes and flushes a buffer.
    public func write(_ buffer: ByteBuffer) async throws {
        guard buffer.readableBytes > 0 else { return }
        try await writeBuffer(buffer)
    }

    /// Writes and flushes a UTF-8 string.
    public func write(_ string: String) async throws {
        try await write(ByteBuffer(string: string))
    }

    /// Writes and flushes raw data.
    public func write(_ data: Data) async throws {
        try await write(ByteBuffer(bytes: data))
    }

    /// Writes and flushes a ``Body``.
    public func write(_ body: Body) async throws {
        try await write(body.buffer)
    }
}
