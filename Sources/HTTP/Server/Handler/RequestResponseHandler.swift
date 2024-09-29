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

        prepareAndWrite(
            response: response,
            for: request,
            in: context
        )
    }
}

extension RequestResponseHandler {
    private func prepareAndWrite(
        response: Response,
        for request: Request,
        in context: ChannelHandlerContext
    ) {
        let future = processMiddleware(
            server.middleware,
            request: request,
            response: response
        )
        future.whenSuccess { [weak self] request, response in
            self?.write(
                response: response as? Response ?? .init("\(response)"),
                for: request,
                in: context
            )
        }
        future.whenFailure { [weak self] error in
            guard let self else { return }
            let future: EventLoopFuture<(Request, Encodable)>

            if let middlewareError = error as? MiddlewareError {
                future = processMiddleware(
                    server.errorMiddleware,
                    request: middlewareError.request,
                    response: middlewareError.response,
                    error: middlewareError.error
                )
            } else {
                future = processMiddleware(
                    server.errorMiddleware,
                    request: request,
                    response: response,
                    error: error
                )
            }

            future.whenSuccess { [weak self] request, response in
                self?.write(
                    response: response as? Response ?? .init("\(response)"),
                    for: request,
                    in: context
                )
            }
            future.whenFailure { [weak self] error in
                self?.server.logger.error("Server error: \(error)")
                self?.write(
                    response: .init(status: .internalServerError),
                    for: request,
                    in: context
                )
            }
        }
    }

    private func write(
        response: Response,
        for request: Request,
        in context: ChannelHandlerContext
    ) {
        if request.version.major >= Version.Major.two.rawValue {
            context.write(
                wrapOutboundOut(response),
                promise: nil
            )
        } else {
            let future = context.write(wrapOutboundOut(response))
            future.whenComplete { _ in
                if response.headers.has("close") {
                    context.close(
                        mode: .output,
                        promise: nil
                    )
                }
            }
        }
    }
}

extension RequestResponseHandler {
    private func handle(
        request: Request,
        response: Encodable
    ) async throws -> Encodable {
        if let onReceive = server.onReceive {
            let result = try await onReceive(request)

            if let response = result as? Response {
                return response
            } else {
                if var response = response as? Response {
                    response.body = .init(string: "\(result)")
                    return response
                }
            }
        }

        return response
    }

    private func processMiddleware(
        _ middleware: [Middleware],
        request: Request,
        response: Encodable,
        nextIndex index: Int = 0
    ) -> EventLoopFuture<(Request, Encodable)> {
        let promise = request.eventLoop.makePromise(of: (Request, Encodable).self)
        promise.completeWithTask { [weak self] in
            guard let self else { return (request, response) }
            let lastIndex = middleware.count - 1

            if index > lastIndex {
                do {
                    let response = try await handle(
                        request: request,
                        response: response
                    )
                    return (request, response)
                } catch {
                    throw MiddlewareError(
                        request: request,
                        response: response,
                        error: error
                    )
                }
            }

            do {
                let response = try await middleware[index].handle(request: request) { [weak self] request in
                    guard let self else { return response }
                    return try await processMiddleware(
                        middleware,
                        request: request,
                        response: response,
                        nextIndex: index + 1
                    ).get().1
                }

                return (request, response)
            } catch {
                throw MiddlewareError(
                    request: request,
                    response: response,
                    error: error
                )
            }
        }

        return promise.futureResult
    }

    private func processMiddleware(
        _ middleware: [ErrorMiddleware],
        request: Request,
        response: Encodable,
        error: Error,
        nextIndex index: Int = 0
    ) -> EventLoopFuture<(Request, Encodable)> {
        let promise = request.eventLoop.makePromise(of: (Request, Encodable).self)
        promise.completeWithTask {
            let lastIndex = middleware.count - 1

            if index > lastIndex {
                throw error
            }

            let response = try await middleware[index].handle(
                request: request,
                error: error
            ) { [weak self] request, error in
                guard let self else { return response }
                return try await processMiddleware(
                    middleware,
                    request: request,
                    response: response,
                    error: error,
                    nextIndex: index + 1
                ).get().1
            }

            return (request, response)
        }

        return promise.futureResult
    }
}

struct MiddlewareError: Error {
    let request: Request
    let response: Encodable
    let error: Error
}
