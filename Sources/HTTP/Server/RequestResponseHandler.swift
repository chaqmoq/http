import NIO
import NIOHTTP1

final class RequestResponseHandler: ChannelInboundHandler {
    typealias InboundIn = Request
    typealias OutboundOut = Response

    let server: Server

    init(server: Server) {
        self.server = server
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var request = unwrapInboundIn(data)
        request.parseBody()

        var response = Response()

        if let onReceive = server.onReceive {
            response = onReceive(request)
        }

        if response.headers[.server] == nil {
            response.headers[.server] = server.configuration.serverName
        }

        if request.version.major < ProtocolVersion.Major.two.rawValue {
            if let connection = request.headers[.connection] {
                response.headers[.connection] = connection
            } else {
                if request.version.major == ProtocolVersion.Major.one.rawValue && request.version.minor >= 1 {
                    response.headers[.connection] = "keep-alive"
                } else {
                    response.headers[.connection] = "close"
                }
            }
        }

        if request.method == .HEAD || response.status == .noContent {
            response.body = .init()
        }

        if request.version.major >= ProtocolVersion.Major.two.rawValue {
            context.write(wrapOutboundOut(response), promise: nil)
        } else {
            let future = context.write(wrapOutboundOut(response))

            if response.headers[.connection] == "close" {
                future.whenComplete { _ in
                    context.close(mode: .output, promise: nil)
                }
            }
        }
    }
}
