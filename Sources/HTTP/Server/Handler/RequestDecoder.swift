import NIO
import NIOHTTP1

final class RequestDecoder: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = Request

    private(set) var state: State

    init() {
        state = .idle
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = unwrapInboundIn(data)

        switch requestPart {
        case let .head(head):
            switch state {
            case .idle:
                let method = Request.Method(rawValue: head.method.rawValue) ?? .HEAD
                let uri = URI(head.uri) ?? .default
                let version = Version(
                    major: head.version.major,
                    minor: head.version.minor
                )
                var headers = Headers()

                for header in head.headers {
                    headers.set(.init(name: header.name, value: header.value))
                }

                var request = Request(
                    eventLoop: context.eventLoop,
                    method: method,
                    uri: uri,
                    version: version,
                    headers: headers
                )

                state = .decoding(request)
            case .decoding: assertionFailure("\(type(of: self))'s state is invalid: \(state)")
            }
        case let .body(chunk):
            switch state {
            case .idle: assertionFailure("\(type(of: self))'s state is invalid: \(state)")
            case var .decoding(request):
                if let bytes = chunk.getBytes(at: 0, length: chunk.readableBytes) {
                    request.body.append(bytes: bytes)
                }

                state = .decoding(request)
            }
        case .end:
            switch state {
            case .idle: assertionFailure("\(type(of: self))'s state is invalid: \(state)")
            case let .decoding(request): context.fireChannelRead(wrapInboundOut(request))
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
