public typealias Responder = (Request) async throws -> Response
public typealias ErrorResponder = (Request, Error) async throws -> Response

public protocol Middleware {
    func handle(
        request: Request,
        responder: @escaping Responder
    ) async throws -> Response
}

public extension Middleware {
    func handle(
        request: Request,
        responder: @escaping Responder
    ) async throws -> Response {
        try await responder(request)
    }
}

public protocol ErrorMiddleware {
    func handle(
        request: Request,
        error: Error,
        responder: @escaping ErrorResponder
    ) async throws -> Response
}

public extension ErrorMiddleware {
    func handle(
        request: Request,
        error: Error,
        responder: @escaping ErrorResponder
    ) async throws -> Response {
        try await responder(request, error)
    }
}
