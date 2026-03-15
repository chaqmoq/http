import NIO
import NIOHTTP1

final class RequestDecoder: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = Request

    private(set) var state: State
    private let maxBodySize: Int?

    init(maxBodySize: Int? = nil) {
        self.maxBodySize = maxBodySize
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

                // Allocate from the channel's pool so the accumulation buffer
                // participates in NIO's recycling system instead of the system allocator.
                state = .decoding(request, buffer: context.channel.allocator.buffer(capacity: 0))
            case .decoding:
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
            case .decoding(let request, var buffer):
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
                state = .decoding(request, buffer: buffer)
            }
        case .end:
            switch state {
            case .idle:
                // Receiving .end before .head is a protocol violation.
                context.fireErrorCaught(ChannelError.inappropriateOperationForState)
                context.close(mode: .all, promise: nil)
                return
            case .decoding(var request, let buffer):
                // Assign body once here so that setParametersAndFiles() runs exactly
                // once on the complete body rather than O(n) times on partial chunks.
                // Body(_:) adopts the ByteBuffer directly — no [UInt8] copy.
                if buffer.readableBytes > 0 {
                    request.body = Body(buffer)
                }

                context.fireChannelRead(wrapInboundOut(request))
            }

            state = .idle
        }
    }
}

extension RequestDecoder {
    enum State {
        case idle
        /// The request head has been received. Incoming body chunks are accumulated
        /// into `buffer` using `writeImmutableBuffer` (no per-chunk heap copy).
        /// `Body(buffer)` is assigned exactly once at `.end`, which triggers
        /// `setParametersAndFiles()` a single time on the complete body.
        case decoding(Request, buffer: ByteBuffer)
    }
}
