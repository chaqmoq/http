/// A closure type that handles a request and returns an encodable response.
public typealias Responder = (Request) async throws -> Encodable

/// A closure type that handles a request and an error, returning an encodable response.
public typealias ErrorResponder = (Request, Error) async throws -> Encodable

/// A component that intercepts requests before they reach the application handler.
///
/// Implement this protocol to create reusable request processing logic such as
/// authentication, logging, rate-limiting, or header injection. Call `responder(request)`
/// to forward the request to the next middleware or the application handler.
///
/// ```swift
/// struct TimingMiddleware: Middleware {
///     func handle(request: Request, responder: @escaping Responder) async throws -> Encodable {
///         let start = Date()
///         let response = try await responder(request)
///         print("Request handled in \(Date().timeIntervalSince(start))s")
///         return response
///     }
/// }
/// ```
public protocol Middleware {
    /// Handles an incoming request.
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request.
    ///   - responder: A closure to invoke the next middleware or the application handler.
    /// - Returns: The HTTP response to send to the client.
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

/// A component that handles errors thrown by request middleware or the application handler.
///
/// Implement this protocol to provide custom error responses, log errors, or perform
/// fallback logic when a middleware or the ``Server/onReceive`` closure throws.
///
/// ```swift
/// struct JSONErrorMiddleware: ErrorMiddleware {
///     func handle(request: Request, error: Error, responder: @escaping ErrorResponder) async throws -> Encodable {
///         Response("{\"error\":\"\(error)\"}", status: .internalServerError)
///     }
/// }
/// ```
public protocol ErrorMiddleware {
    /// Handles an error thrown during request processing.
    ///
    /// - Parameters:
    ///   - request: The original HTTP request.
    ///   - error: The error that was thrown.
    ///   - responder: A closure to invoke the next error middleware.
    /// - Returns: The HTTP response to send to the client.
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
