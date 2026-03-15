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

                state = .decoding(request, buffer: [])
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
            case let .decoding(request, buffer: buffer):
                guard let bytes = chunk.getBytes(at: 0, length: chunk.readableBytes) else {
                    break
                }

                // Enforce the optional body size limit before accumulating the chunk.
                // The check uses the raw buffer count, before Body is constructed, so
                // setParametersAndFiles() is never called on partial data.
                if let maxBodySize, buffer.count + bytes.count > maxBodySize {
                    context.fireErrorCaught(ServerError.bodyTooLarge)
                    context.close(mode: .all, promise: nil)
                    state = .idle
                    return
                }

                state = .decoding(request, buffer: buffer + bytes)
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
                if !buffer.isEmpty {
                    request.body = Body(bytes: buffer)
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
        /// The request head has been received. Raw body bytes are accumulated in
        /// `buffer` and assigned to `request.body` in a single operation on `.end`,
        /// avoiding O(n²) re-parsing of multipart/form-data bodies.
        case decoding(Request, buffer: [UInt8])
    }
}
