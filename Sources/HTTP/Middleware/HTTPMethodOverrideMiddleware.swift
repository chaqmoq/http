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
/// ## Security
///
/// By default the override is deliberately restricted:
///
/// - Only **`POST`** requests may be overridden (``Options/allowedSourceMethods``).
///   Overriding safe methods like `GET` would let a simple link or prefetcher trigger
///   destructive actions and could poison caches that key on the original method.
/// - The override may only target **`DELETE`, `PATCH`, `PUT`**
///   (``Options/allowedTargetMethods``). Tunneling to `GET`/`HEAD` (cache interference),
///   `TRACE`, or `CONNECT` is refused.
///
/// - Important: Register this middleware **before** any middleware that makes decisions
///   based on `request.method` (authorization, CSRF protection, routing guards).
///   Method-based checks that run before the override sees the request are evaluated
///   against the *original* method and can be bypassed by tunneling.
///
/// ```swift
/// server.middleware = [
///     HTTPMethodOverrideMiddleware(), // first: normalises the method…
///     CSRFMiddleware(),               // …so later checks see the effective method
/// ]
/// ```
public struct HTTPMethodOverrideMiddleware: Middleware {
    /// Configuration for which methods may be overridden, and into what.
    public struct Options {
        /// Request methods eligible for override. Defaults to `[.POST]`.
        public var allowedSourceMethods: Set<Request.Method>

        /// Methods the override may switch to. Defaults to `[.DELETE, .PATCH, .PUT]`.
        public var allowedTargetMethods: Set<Request.Method>

        /// Initializes override options.
        ///
        /// - Parameters:
        ///   - allowedSourceMethods: Methods eligible for override. Defaults to `[.POST]`.
        ///   - allowedTargetMethods: Methods the override may produce.
        ///     Defaults to `[.DELETE, .PATCH, .PUT]`.
        public init(
            allowedSourceMethods: Set<Request.Method> = [.POST],
            allowedTargetMethods: Set<Request.Method> = [.DELETE, .PATCH, .PUT]
        ) {
            self.allowedSourceMethods = allowedSourceMethods
            self.allowedTargetMethods = allowedTargetMethods
        }
    }

    /// The override policy applied to each request.
    public var options: Options

    /// Initializes a new `HTTPMethodOverrideMiddleware`.
    ///
    /// - Parameter options: The override policy. Defaults to the restricted policy
    ///   described in the type documentation (`POST` → `DELETE`/`PATCH`/`PUT`).
    public init(options: Options = .init()) {
        self.options = options
    }

    /// See ``Middleware/handle(request:responder:)``.
    public func handle(
        request: Request,
        responder: @escaping Responder
    ) async throws -> Encodable {
        // Only requests with an eligible source method may be overridden.
        guard options.allowedSourceMethods.contains(request.method) else {
            return try await responder(request)
        }

        var request = request

        if let methodName: String = request.getParameter("_method"),
           let method = Request.Method(rawValue: methodName),
           options.allowedTargetMethods.contains(method) {
            request.method = method
        } else if
            let methodName = request.headers.get(.xHTTPMethodOverride),
            let method = Request.Method(rawValue: methodName),
            options.allowedTargetMethods.contains(method) {
            request.method = method
        }

        return try await responder(request)
    }
}
