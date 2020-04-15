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
        let request = unwrapInboundIn(data)
        var response = Response()

        if response.headers[Header.server.rawValue] == nil {
            response.headers[Header.server.rawValue] = server.configuration.serverName
        }

        if request.version.major < Version.Major.two.rawValue {
            let connectionKey = Header.connection.rawValue

            if let connection = request.headers[connectionKey] {
                response.headers[connectionKey] = connection
            } else {
                if request.version.major == Version.Major.one.rawValue && request.version.minor >= 1 {
                    response.headers[connectionKey] = "keep-alive"
                } else {
                    response.headers[connectionKey] = "close"
                }
            }
        }

        if request.method == .HEAD || response.status == .noContent {
            response.body = .init()
        }

        if let onReceive = server.onReceive {
            response = onReceive(request)
        }

        if request.version.major >= Version.Major.two.rawValue {
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
