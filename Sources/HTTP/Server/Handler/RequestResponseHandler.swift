@preconcurrency import NIO
import NIOHTTP1
import Foundation

private final class Box<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

final class RequestResponseHandler: ChannelInboundHandler, RemovableChannelHandler, @unchecked Sendable {
    typealias InboundIn = Request
    typealias OutboundOut = Response

    let server: Server
    /// Non-nil on HTTP/2 connections only. Receives push promises before the
    /// main response is written so they can be sent as PUSH_PROMISE frames.
    let pushHandler: HTTP2PushHandler?

    init(server: Server, pushHandler: HTTP2PushHandler? = nil) {
        self.server = server
        self.pushHandler = pushHandler
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let request = unwrapInboundIn(data)

        // Reject an unparseable request target with 400 Bad Request before running any
        // middleware or the application handler. Routing/authorization must never see a
        // malformed target that silently fell back to "/".
        guard request.isURIValid else {
            server.onError?(ServerError.invalidURI, context.eventLoop)
            write(response: Response(status: .badRequest), for: request, in: context)
            return
        }

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
        let ctxBox = Box(context)
        let future = processMiddleware(
            server.middleware,
            request: request,
            response: response
        )
        future.whenSuccess { [weak self, ctxBox] request, response in
            ctxBox.value.eventLoop.execute { [self, ctxBox] in
                self?.write(
                    response: response as? Response ?? .init("\(response)"),
                    for: request,
                    in: ctxBox.value
                )
            }
        }
        future.whenFailure { [weak self, ctxBox] error in
            guard let self else { return }
            let future: EventLoopFuture<(Request, any Encodable & Sendable)>

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

            future.whenSuccess { [self, ctxBox] request, response in
                ctxBox.value.eventLoop.execute { [self, ctxBox] in
                    self.write(
                        response: response as? Response ?? .init("\(response)"),
                        for: request,
                        in: ctxBox.value
                    )
                }
            }
            future.whenFailure { [self, ctxBox] error in
                self.server.logger.error("Server error: \(error)")
                ctxBox.value.eventLoop.execute { [self, ctxBox] in
                    self.write(
                        response: .init(status: .internalServerError),
                        for: request,
                        in: ctxBox.value
                    )
                }
            }
        }
    }

    private func write(
        response: Response,
        for request: Request,
        in context: ChannelHandlerContext
    ) {
        var response = response

        // Mirror the negotiated HTTP version into the response so that the
        // ResponseEncoder produces the correct status line (e.g. "HTTP/2.0 200 OK"
        // for an HTTP/2 connection rather than always emitting "HTTP/1.1").
        response.version = request.version

        // Apply the configured Server header to every response. This is done here
        // (rather than in channelRead) so it survives when onReceive returns a
        // fresh Response that has no Server header of its own.
        if let serverName = server.configuration.serverName {
            response.headers.set(.init(name: .server, value: serverName))
        }

        // Notify the HTTP/2 push handler of any queued push promises. The handler
        // sends PUSH_PROMISE frames before forwarding the first response frame,
        // satisfying RFC 7540 §8.2's ordering requirement.
        if !request.pushes.isEmpty {
            pushHandler?.enqueue(request.pushes, authority: request.headers.get(.host) ?? "")
        }

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
            let isConnectionClose = response.headers.get(.connection)?.lowercased() == "close"
            let ctxBox = Box(context)
            let future = context.write(wrapOutboundOut(response))
            future.whenComplete { [ctxBox] _ in
                if isConnectionClose {
                    ctxBox.value.close(
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
        response: any Encodable & Sendable
    ) async throws -> any Encodable & Sendable {
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
        response: any Encodable & Sendable
    ) -> EventLoopFuture<(Request, any Encodable & Sendable)> {
        let promise = request.eventLoop.makePromise(of: (Request, any Encodable & Sendable).self)
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
        response: any Encodable & Sendable
    ) async throws -> (Request, any Encodable & Sendable) {
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
        response: any Encodable & Sendable,
        error: Error
    ) -> EventLoopFuture<(Request, any Encodable & Sendable)> {
        let promise = request.eventLoop.makePromise(of: (Request, any Encodable & Sendable).self)
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
        response: any Encodable & Sendable,
        error: Error
    ) async throws -> (Request, any Encodable & Sendable) {
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
    let response: any Encodable & Sendable
    let error: Error
}
