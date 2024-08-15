public typealias Responder = (Request) async throws -> Encodable
public typealias ErrorResponder = (Request, Error) async throws -> Encodable

public protocol Middleware {
    func handle(
        request: Request,
        responder: @escaping Responder
    ) async throws -> Encodable
}

public extension Middleware {
    func handle(
        request: Request,
        responder: @escaping Responder
    ) async throws -> Encodable {
        try await responder(request)
    }
}

public protocol ErrorMiddleware {
    func handle(
        request: Request,
        error: Error,
        responder: @escaping ErrorResponder
    ) async throws -> Encodable
}

public extension ErrorMiddleware {
    func handle(
        request: Request,
        error: Error,
        responder: @escaping ErrorResponder
    ) async throws -> Encodable {
        try await responder(request, error)
    }
}
