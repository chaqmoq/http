import NIO
import NIOHTTP1

final class RequestDecoder: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = Request

    /// Errors that `RequestDecoder` can raise as channel errors.
    enum Error: Swift.Error {
        /// The request body exceeded the configured `maxBodySize` limit.
        case bodyTooLarge
    }

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

                state = .decoding(request)
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
            case var .decoding(request):
                if let bytes = chunk.getBytes(at: 0, length: chunk.readableBytes) {
                    // Enforce the optional body size limit before accumulating the chunk.
                    if let maxBodySize, request.body.count + bytes.count > maxBodySize {
                        context.fireErrorCaught(Error.bodyTooLarge)
                        context.close(mode: .all, promise: nil)
                        state = .idle
                        return
                    }

                    request.body.append(bytes: bytes)
                }

                state = .decoding(request)
            }
        case .end:
            switch state {
            case .idle:
                // Receiving .end before .head is a protocol violation.
                context.fireErrorCaught(ChannelError.inappropriateOperationForState)
                context.close(mode: .all, promise: nil)
                return
            case let .decoding(request):
                context.fireChannelRead(wrapInboundOut(request))
            }

            state = .idle
        }
    }
}

extension RequestDecoder {
    enum State {
        case idle
        case decoding(Request)
    }
}
