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

        if let serverName = server.configuration.serverName {
            response.headers.set(serverName, for: .server)
        }

        if request.version.major < Version.Major.two.rawValue {
            let connectionKey: HeaderName = .connection

            if let connection = request.headers.value(for: connectionKey) {
                response.headers.set(connection, for: connectionKey)
            } else {
                if request.version.major == Version.Major.one.rawValue && request.version.minor >= 1 {
                    response.headers.set("keep-alive", for: connectionKey)
                } else {
                    response.headers.set("close", for: connectionKey)
                }
            }
        }

        if request.method == .HEAD || response.status == .noContent {
            response.body = .init()
        }

        prepareAndWrite(response: response, for: request, in: context)
    }

    private func prepareAndWrite(response: Response, for request: Request, in context: ChannelHandlerContext) {
        if let onReceive = server.onReceive {
            let result = onReceive(request, context.eventLoop)

            if let result = result as? EventLoopFuture<Any> {
                result.whenSuccess { [weak self] result in
                    if let response = result as? Response {
                        self?.write(response: response, for: request, in: context)
                    } else {
                        var response = response
                        response.body = .init(string: String(describing: result))
                        self?.write(response: response, for: request, in: context)
                    }
                }
                result.whenFailure { error in
                    context.fireErrorCaught(error)
                }
            } else {
                if let response = result as? Response {
                    write(response: response, for: request, in: context)
                } else {
                    var response = response
                    response.body = .init(string: String(describing: result))
                    write(response: response, for: request, in: context)
                }
            }
        } else {
            write(response: response, for: request, in: context)
        }
    }

    private func write(response: Response, for request: Request, in context: ChannelHandlerContext) {
        if request.version.major >= Version.Major.two.rawValue {
            context.write(wrapOutboundOut(response), promise: nil)
        } else {
            let future = context.write(wrapOutboundOut(response))

            if response.headers.has("close") {
                future.whenComplete { _ in
                    context.close(mode: .output, promise: nil)
                }
            }
        }
    }
}
