import NIO

/// An `AsyncSequence` of `ByteBuffer` chunks representing an HTTP request body as it
/// arrives over the network.
///
/// `BodyStream` is produced by `RequestDecoder` when the server is configured with a
/// ``Server/Configuration/streamingBodyThreshold`` and an incoming request body meets the
/// streaming criteria. The request handler receives the ``Request`` immediately — without
/// waiting for the full body — and may consume chunks lazily:
///
/// ```swift
/// server.onReceive = { request in
///     if let stream = request.bodyStream {
///         for try await chunk in stream {
///             process(chunk)
///         }
///     }
///     return Response("done")
/// }
/// ```
///
/// For convenience, ``collect(maxSize:)`` gathers all chunks into a single ``Body``.
/// ``Request/collectBody(maxSize:)`` does the same and caches the result on the request,
/// making it the idiomatic way to consume a streaming body when the full content is needed:
///
/// ```swift
/// server.onReceive = { request in
///     let body = try await request.collectBody()
///     let payload = try body.decode(MyPayload.self)
///     return Response("ok")
/// }
/// ```
///
/// ## Channel lifecycle
///
/// The stream is automatically finished with an error when the underlying TCP connection
/// closes mid-request, so any pending `for try await` loop will throw rather than hang.
///
/// - Important: `BodyStream` is a **single-consumer** sequence. Starting a second
///   `makeAsyncIterator()` call after the first has begun consuming the stream
///   produces undefined behavior — each chunk is delivered exactly once.
public final class BodyStream: AsyncSequence, @unchecked Sendable {
    public typealias Element = ByteBuffer

    private let inner: AsyncThrowingStream<ByteBuffer, Error>

    // Stored so RequestDecoder can feed chunks without going through the sequence.
    let continuation: AsyncThrowingStream<ByteBuffer, Error>.Continuation

    init() {
        var cont: AsyncThrowingStream<ByteBuffer, Error>.Continuation!
        inner = AsyncThrowingStream { cont = $0 }
        continuation = cont
    }

    // MARK: - Internal feed API (used by RequestDecoder on the event-loop thread)

    /// Delivers the next body chunk to any waiting consumer.
    func yield(_ buffer: ByteBuffer) {
        continuation.yield(buffer)
    }

    /// Signals normal end-of-stream, or propagates an error to the consumer.
    func finish(throwing error: Error? = nil) {
        if let error {
            continuation.finish(throwing: error)
        } else {
            continuation.finish()
        }
    }

    // MARK: - AsyncSequence conformance

    public func makeAsyncIterator() -> AsyncThrowingStream<ByteBuffer, Error>.AsyncIterator {
        inner.makeAsyncIterator()
    }
}

// MARK: - Collect

extension BodyStream {
    /// Collects all chunks from the stream into a single ``Body``.
    ///
    /// Chunks are written into a single `ByteBuffer` without intermediate copies
    /// (NIO's `writeBuffer` appends readable bytes in-place).
    ///
    /// - Parameter maxSize: When non-`nil`, throws ``BodyStreamError/tooLarge`` as soon
    ///   as the accumulated byte count would exceed this value. Defaults to `nil` (no limit).
    /// - Returns: A fully buffered ``Body`` containing all received bytes.
    /// - Throws: ``BodyStreamError/tooLarge`` or any error injected by ``finish(throwing:)``.
    public func collect(maxSize: Int? = nil) async throws -> Body {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)

        for try await chunk in self {
            if let maxSize, buffer.readableBytes + chunk.readableBytes > maxSize {
                throw BodyStreamError.tooLarge
            }

            var mutableChunk = chunk
            buffer.writeBuffer(&mutableChunk)
        }

        return Body(buffer)
    }
}

// MARK: - BodyStreamError

/// Errors that can be thrown while consuming a ``BodyStream``.
public enum BodyStreamError: Error, Equatable, CustomStringConvertible {
    /// The accumulated body size exceeded the caller-supplied `maxSize` limit.
    case tooLarge

    public var description: String {
        switch self {
        case .tooLarge:
            return "Body stream exceeded the maximum allowed size."
        }
    }
}
