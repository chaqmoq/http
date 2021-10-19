public struct HTTPMethodOverrideMiddleware: Middleware {
    public init() {}

    public func handle(request: Request, nextHandler: @escaping (Request) -> Response) -> Response {
        var request = request

        if let methodName = request.parameters["_method"], let method = Request.Method(rawValue: methodName) {
            request.method = method
        } else if let methodName = request.headers.get(.xHTTPMethodOverride),
           let method = Request.Method(rawValue: methodName) {
            request.method = method
        }

        return nextHandler(request)
    }
}
