import NIO
import NIOHTTP1

final class RequestDecoder: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = Request

    let server: Server
    private(set) var state: State

    init(server: Server) {
        self.server = server
        state = .idle
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = unwrapInboundIn(data)

        switch requestPart {
        case .head(let head):
            switch state {
            case .idle:
                let version = Version(major: head.version.major, minor: head.version.minor)
                var request: Request

                if let method = Request.Method(rawValue: head.method.rawValue), let uri = URI(string: head.uri) {
                    request = Request(method: method, uri: uri, version: version)
                } else if let method = Request.Method(rawValue: head.method.rawValue) {
                    request = Request(method: method, version: version)
                } else if let uri = URI(string: head.uri) {
                    request = Request(uri: uri, version: version)
                } else {
                    request = Request(version: version)
                }

                for header in head.headers {
                    request.headers.set(value: header.value, for: header.name)
                }

                state = .decoding(request)
            case .decoding: assertionFailure("\(type(of: self))'s state is invalid: \(state)")
            }
        case .body(let chunk):
            switch state {
            case .idle: assertionFailure("\(type(of: self))'s state is invalid: \(state)")
            case .decoding(var request):
                if let bytes = chunk.getBytes(at: 0, length: chunk.readableBytes) {
                    request.body.append(bytes: bytes)
                }

                state = .decoding(request)
            }
        case .end:
            switch state {
            case .idle: assertionFailure("\(type(of: self))'s state is invalid: \(state)")
            case .decoding(let request): context.fireChannelRead(wrapInboundOut(request))
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
