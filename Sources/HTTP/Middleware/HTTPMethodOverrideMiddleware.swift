/// Middleware that overrides the HTTP method based on a form parameter or request header.
///
/// Some HTTP clients (notably HTML forms) only support `GET` and `POST`. This middleware
/// allows those clients to tunnel other methods by:
///
/// 1. Adding a `_method` form field to the request body (e.g. `_method=DELETE`).
/// 2. Setting the `X-HTTP-Method-Override` request header to the desired method name.
///
/// The form parameter takes precedence over the header. If neither is present the request
/// is forwarded unchanged.
///
/// ```swift
/// server.middleware = [HTTPMethodOverrideMiddleware()]
/// ```
public struct HTTPMethodOverrideMiddleware: Middleware {
    /// Initializes a new `HTTPMethodOverrideMiddleware`.
    public init() {}

    /// See ``Middleware/handle(request:responder:)``.
    public func handle(
        request: Request,
        responder: @escaping Responder
    ) async throws -> Encodable {
        var request = request

        if let methodName: String = request.getParameter("_method"),
           let method = Request.Method(rawValue: methodName) {
            request.method = method
        } else if
            let methodName = request.headers.get(.xHTTPMethodOverride),
            let method = Request.Method(rawValue: methodName) {
            request.method = method
        }

        return try await responder(request)
    }
}
