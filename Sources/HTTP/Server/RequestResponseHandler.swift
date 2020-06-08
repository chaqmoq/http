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
            response.headers.set(value: serverName, for: Header.server.rawValue)
        }

        if request.version.major < Version.Major.two.rawValue {
            let connectionKey = Header.connection.rawValue

            if let connection = request.headers.value(for: connectionKey) {
                response.headers.set(value: connection, for: connectionKey)
            } else {
                if request.version.major == Version.Major.one.rawValue && request.version.minor >= 1 {
                    response.headers.set(value: "keep-alive", for: connectionKey)
                } else {
                    response.headers.set(value: "close", for: connectionKey)
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

            if let string = result as? String {
                var response = response
                response.body = .init(string: string)
                write(response: response, for: request, in: context)
            } else if let response = result as? Response {
                write(response: response, for: request, in: context)
            } else if let futureResponse = result as? EventLoopFuture<String> {
                futureResponse.whenSuccess { [weak self] string in
                    var response = response
                    response.body = .init(string: string)
                    self?.write(response: response, for: request, in: context)
                }
                futureResponse.whenFailure { error in
                    context.fireErrorCaught(error)
                }
            } else if let futureResponse = result as? EventLoopFuture<Response> {
                futureResponse.whenSuccess { [weak self] response in
                    self?.write(response: response, for: request, in: context)
                }
                futureResponse.whenFailure { error in
                    context.fireErrorCaught(error)
                }
            } else {
                var response = response
                response.status = .internalServerError
                write(response: response, for: request, in: context)
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

            if response.headers.has(key: "close") {
                future.whenComplete { _ in
                    context.close(mode: .output, promise: nil)
                }
            }
        }
    }
}
