import NIO
import NIOHTTP1
import Foundation

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
            response.headers.set(.init(name: .server, value: serverName))
        }

        if request.version.major < Version.Major.two.rawValue {
            let connectionKey: HeaderName = .connection

            if let connection = request.headers.get(connectionKey) {
                response.headers.set(.init(name: connectionKey, value: connection))
            } else {
                if request.version.major == Version.Major.one.rawValue, request.version.minor >= 1 {
                    response.headers.set(.init(name: connectionKey, value: "keep-alive"))
                } else {
                    response.headers.set(.init(name: connectionKey, value: "close"))
                }
            }
        }

        if request.method == .HEAD || response.status == .noContent {
            response.body = .init()
        }

        prepareAndWrite(response: response, for: request, in: context)
    }

    private func prepareAndWrite(response: Response, for request: Request, in context: ChannelHandlerContext) {
        let middleware = server.middleware
        let lastIndex = middleware.count - 1
        var (request, response, index) = handle(
            request: request,
            response: response,
            middleware: middleware,
            lastIndex: lastIndex
        )

        if index <= lastIndex {
            write(response: response, for: request, in: context)
        } else {
            if let onReceive = server.onReceive {
                let result = onReceive(request, context.eventLoop)

                if let result = result as? Response {
                    response = result
                } else {
                    response.body = .init(string: "\(result)")
                }
            }

            (request, response, index) = handle(
                request: request,
                response: response,
                middleware: middleware.reversed(),
                lastIndex: lastIndex
            )

            write(response: response, for: request, in: context)
        }
    }

    private func handle(
        request: Request,
        response: Response,
        middleware: [Middleware],
        nextIndex index: Int = 0,
        lastIndex: Int
    ) -> (Request, Response, Int) {
        if index <= lastIndex {
            let response = middleware[index].handle(request: request) { [self] request in
                handle(
                    request: request,
                    response: response,
                    middleware: middleware,
                    nextIndex: index + 1,
                    lastIndex: lastIndex
                ).1
            }
            return (request, response, index)
        }

        return (request, response, index)
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
