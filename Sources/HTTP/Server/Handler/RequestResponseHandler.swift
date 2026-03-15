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
        var response = response

        if request.method == .HEAD {
            // RFC 9110 §9.3.2: HEAD must not send a body. Content-Length SHOULD reflect
            // the byte size that a GET would return, so we preserve the header value that
            // the handler set, then clear the body without letting body.didSet overwrite it.
            let contentLength = response.headers.get(.contentLength)
            response.body = Body()   // didSet sets Content-Length to "0"

            if let contentLength {
                response.headers.set(.init(name: .contentLength, value: contentLength))
            } else {
                response.headers.remove(.contentLength)
            }
        } else if response.status == .noContent {
            // RFC 9110 §15.3.5: 204 No Content must not include a body or Content-Length.
            response.body = Body()
            response.headers.remove(.contentLength)
        }

        if request.version.major >= Version.Major.two.rawValue {
            context.write(
                wrapOutboundOut(response),
                promise: nil
            )
        } else {
            let future = context.write(wrapOutboundOut(response))
            future.whenComplete { _ in
                if response.headers.get(.connection)?.lowercased() == "close" {
                    context.close(
                        mode: .output,
                        promise: nil
                    )
                }
            }
        }
    }
}

// MARK: - Middleware processing

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

    /// Runs the regular middleware chain.
    ///
    /// Creates a single `EventLoopPromise` + Swift `Task` for the entire chain.
    /// Individual middleware layers recurse through `runMiddleware` as ordinary
    /// async calls — no extra promise or task is allocated per layer.
    private func processMiddleware(
        _ middleware: [Middleware],
        request: Request,
        response: Encodable
    ) -> EventLoopFuture<(Request, Encodable)> {
        let promise = request.eventLoop.makePromise(of: (Request, Encodable).self)
        promise.completeWithTask { [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.runMiddleware(middleware, index: 0, request: request, response: response)
        }
        return promise.futureResult
    }

    private func runMiddleware(
        _ middleware: [Middleware],
        index: Int,
        request: Request,
        response: Encodable
    ) async throws -> (Request, Encodable) {
        guard index < middleware.count else {
            do {
                let response = try await handle(request: request, response: response)
                return (request, response)
            } catch {
                if let middlewareError = error as? MiddlewareError {
                    throw middlewareError
                } else {
                    throw MiddlewareError(request: request, response: response, error: error)
                }
            }
        }

        do {
            let result = try await middleware[index].handle(request: request) { [weak self] req in
                guard let self else { throw CancellationError() }
                return try await self.runMiddleware(middleware, index: index + 1, request: req, response: response).1
            }
            return (request, result)
        } catch {
            if let middlewareError = error as? MiddlewareError {
                throw middlewareError
            } else {
                throw MiddlewareError(request: request, response: response, error: error)
            }
        }
    }

    /// Runs the error middleware chain.
    ///
    /// Same single-task design as `processMiddleware(_:request:response:)`.
    private func processMiddleware(
        _ middleware: [ErrorMiddleware],
        request: Request,
        response: Encodable,
        error: Error
    ) -> EventLoopFuture<(Request, Encodable)> {
        let promise = request.eventLoop.makePromise(of: (Request, Encodable).self)
        promise.completeWithTask { [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.runErrorMiddleware(middleware, index: 0, request: request, response: response, error: error)
        }
        return promise.futureResult
    }

    private func runErrorMiddleware(
        _ middleware: [ErrorMiddleware],
        index: Int,
        request: Request,
        response: Encodable,
        error: Error
    ) async throws -> (Request, Encodable) {
        guard index < middleware.count else {
            throw error
        }

        let result = try await middleware[index].handle(request: request, error: error) { [weak self] req, err in
            guard let self else { throw CancellationError() }
            return try await self.runErrorMiddleware(middleware, index: index + 1, request: req, response: response, error: err).1
        }
        return (request, result)
    }
}

struct MiddlewareError: Error {
    let request: Request
    let response: Encodable
    let error: Error
}
