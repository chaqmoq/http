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

        if response.headers[Header.server.rawValue] == nil {
            response.headers[Header.server.rawValue] = server.configuration.serverName
        }

        if request.version.major < ProtocolVersion.Major.two.rawValue {
            if let connection = request.headers[Header.connection.rawValue] {
                response.headers[Header.connection.rawValue] = connection
            } else {
                if request.version.major == ProtocolVersion.Major.one.rawValue && request.version.minor >= 1 {
                    response.headers[Header.connection.rawValue] = "keep-alive"
                } else {
                    response.headers[Header.connection.rawValue] = "close"
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

            if response.headers[Header.connection.rawValue] == "close" {
                future.whenComplete { _ in
                    context.close(mode: .output, promise: nil)
                }
            }
        }
    }
}
