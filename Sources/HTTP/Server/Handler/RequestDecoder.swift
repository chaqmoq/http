import NIO
import NIOHTTP1

final class RequestDecoder: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = Request

    private(set) var state: State
    private let maxBodySize: Int?

    /// When non-`nil`, bodies with a `Content-Length` exceeding this value (or bodies
    /// with an unknown length, such as chunked transfers) are delivered as a ``BodyStream``
    /// rather than being fully accumulated before the request is forwarded downstream.
    /// `nil` (the default) preserves the original fully-buffered behaviour.
    private let streamingBodyThreshold: Int?

    init(maxBodySize: Int? = nil, streamingBodyThreshold: Int? = nil) {
        self.maxBodySize = maxBodySize
        self.streamingBodyThreshold = streamingBodyThreshold
        state = .idle
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = unwrapInboundIn(data)

        switch requestPart {
        case let .head(head):
            switch state {
            case .idle:
                let method = Request.Method(rawValue: head.method.rawValue) ?? .GET
                let uri = URI(head.uri) ?? .default
                let version = Version(
                    major: head.version.major,
                    minor: head.version.minor
                )
                var headers = Headers()

                for header in head.headers {
                    headers.set(.init(name: header.name, value: header.value))
                }

                let request = Request(
                    eventLoop: context.eventLoop,
                    method: method,
                    uri: uri,
                    version: version,
                    headers: headers
                )

                // Decide whether to buffer or stream this request's body.
                if let threshold = streamingBodyThreshold {
                    let contentLength = head.headers["content-length"].first.flatMap(Int.init)
                    // Stream when the declared body size exceeds the threshold, or when
                    // the length is unknown (chunked transfer encoding or no header).
                    let shouldStream = contentLength.map { $0 > threshold } ?? true

                    if shouldStream {
                        let stream = BodyStream()
                        var streamingRequest = request
                        streamingRequest.bodyStream = stream
                        // Fire the request downstream immediately — the handler receives
                        // it before the body arrives and consumes the stream lazily.
                        context.fireChannelRead(wrapInboundOut(streamingRequest))
                        state = .streaming(stream, bytesReceived: 0)
                        return
                    }
                }

                // Buffered mode: accumulate from the channel's pool allocator.
                state = .collecting(request, buffer: context.channel.allocator.buffer(capacity: 0))

            case .collecting, .streaming:
                // Receiving a second .head without a preceding .end is a protocol violation.
                context.fireErrorCaught(ChannelError.inappropriateOperationForState)
                context.close(mode: .all, promise: nil)
            }

        case let .body(chunk):
            switch state {
            case .idle:
                // Receiving .body before .head is a protocol violation.
                context.fireErrorCaught(ChannelError.inappropriateOperationForState)
                context.close(mode: .all, promise: nil)

            case .collecting(let request, var buffer):
                // Enforce the optional body size limit before accumulating the chunk.
                if let maxBodySize, buffer.readableBytes + chunk.readableBytes > maxBodySize {
                    context.fireErrorCaught(ServerError.bodyTooLarge)
                    context.close(mode: .all, promise: nil)
                    state = .idle
                    return
                }

                // writeImmutableBuffer appends chunk's readable bytes into buffer
                // without mutating chunk — zero-copy when the backing storage is
                // already contiguous (which NIO guarantees for channel reads).
                buffer.writeImmutableBuffer(chunk)
                state = .collecting(request, buffer: buffer)

            case .streaming(let stream, let bytesReceived):
                let newTotal = bytesReceived + chunk.readableBytes
                // Enforce the optional body size limit in streaming mode.
                // Finish the stream with an error so the awaiting handler is unblocked.
                if let maxBodySize, newTotal > maxBodySize {
                    stream.finish(throwing: ServerError.bodyTooLarge)
                    context.close(mode: .all, promise: nil)
                    state = .idle
                    return
                }

                stream.yield(chunk)
                state = .streaming(stream, bytesReceived: newTotal)
            }

        case .end:
            switch state {
            case .idle:
                // Receiving .end before .head is a protocol violation.
                context.fireErrorCaught(ChannelError.inappropriateOperationForState)
                context.close(mode: .all, promise: nil)
                return

            case .collecting(var request, let buffer):
                // Assign body once here so that setParametersAndFiles() runs exactly
                // once on the complete body rather than O(n) times on partial chunks.
                // Body(_:) adopts the ByteBuffer directly — no [UInt8] copy.
                if buffer.readableBytes > 0 {
                    request.body = Body(buffer)
                }

                context.fireChannelRead(wrapInboundOut(request))

            case .streaming(let stream, _):
                // Signal end-of-stream to any consumer awaiting the next chunk.
                stream.finish()
            }

            state = .idle
        }
    }

    /// Propagates upstream errors to any active stream consumer so the `for try await`
    /// loop throws rather than hanging indefinitely.
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        if case .streaming(let stream, _) = state {
            stream.finish(throwing: error)
            state = .idle
        }

        context.fireErrorCaught(error)
    }

    /// Unblocks any active stream consumer when the TCP connection closes unexpectedly.
    func channelInactive(context: ChannelHandlerContext) {
        if case .streaming(let stream, _) = state {
            stream.finish(throwing: ChannelError.ioOnClosedChannel)
            state = .idle
        }

        context.fireChannelInactive()
    }
}

extension RequestDecoder {
    enum State {
        case idle

        /// The request head has been received. Incoming body chunks are accumulated
        /// into `buffer` using `writeImmutableBuffer` (no per-chunk heap copy).
        /// `Body(buffer)` is assigned exactly once at `.end`, which triggers
        /// `setParametersAndFiles()` a single time on the complete body.
        case collecting(Request, buffer: ByteBuffer)

        /// The request has already been forwarded downstream. Body chunks are yielded
        /// to `stream` as they arrive; `stream.finish()` is called at `.end`.
        case streaming(BodyStream, bytesReceived: Int)
    }
}
