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

    func channelRead(context: ChannelHandlerContext, data: NIOAny) async {
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

        await prepareAndWrite(response: response, for: request, in: context)
    }

    private func prepareAndWrite(response: Response, for request: Request, in context: ChannelHandlerContext) async {
        let (request, response) = await handle(
            request: request,
            response: response,
            middleware: server.middleware
        )
        write(response: response, for: request, in: context)
    }

    private func handle(request: Request, response: Response) -> Response {
        var response = response

        if let onReceive = server.onReceive {
            let result = onReceive(request)

            if let result = result as? Response {
                response = result
            } else {
                response.body = .init(string: "\(result)")
            }
        }

        return response
    }

    private func handle(
        request: Request,
        response: Response,
        middleware: [Middleware],
        nextIndex index: Int = 0
    ) async -> (Request, Response) {
        let lastIndex = middleware.count - 1

        if index > lastIndex {
            let response = handle(request: request, response: response)
            return (request, response)
        }

        var request = request
        let response = await middleware[index].handle(request: request) { [self] mutatedRequest in
            request = mutatedRequest

            if index == lastIndex {
                return handle(request: request, response: response)
            }

            return await handle(
                request: request,
                response: response,
                middleware: middleware,
                nextIndex: index + 1
            ).1
        }

        return (request, response)
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
