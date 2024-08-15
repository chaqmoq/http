public struct HTTPMethodOverrideMiddleware: Middleware {
    public init() {}

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
