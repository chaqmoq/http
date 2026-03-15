import Foundation

/// Middleware that adds Cross-Origin Resource Sharing (CORS) headers to responses.
///
/// Attach `CORSMiddleware` to the server's middleware chain to allow web browsers from
/// different origins to make requests to your API. By default all origins are permitted
/// and the standard safe methods are allowed.
///
/// ```swift
/// server.middleware = [
///     CORSMiddleware(options: .init(
///         allowedOrigin: .origins(["https://example.com"]),
///         allowedMethods: [.GET, .POST],
///         maxAge: 3600
///     ))
/// ]
/// ```
public struct CORSMiddleware: Middleware {
    /// The CORS policy options applied to each request.
    public var options: Options

    /// Initializes the middleware with the given CORS options.
    ///
    /// - Parameter options: The CORS policy. Defaults to permitting all origins.
    public init(options: Options = .init()) {
        self.options = options
    }

    public func handle(
        request: Request,
        responder: @escaping Responder
    ) async throws -> Encodable {
        guard request.headers.get(.origin) != nil else { return try await responder(request) }
        let encodable = request.isPreflight ? Response(status: .noContent) : try await responder(request)
        var response = encodable as? Response ?? .init("\(encodable)")

        setAllowCredentialsHeader(response: &response)
        setAllowHeadersHeader(request: request, response: &response)
        setAllowMethodsHeader(response: &response)
        setAllowOriginHeader(request: request, response: &response)
        setExposeHeadersHeader(response: &response)
        setMaxAgeHeader(response: &response)

        return response
    }
}

extension CORSMiddleware {
    public struct Options {
        public var allowCredentials: Bool
        public var allowedHeaders: [String]?
        public var allowedMethods: [Request.Method]
        public var allowedOrigin: AllowedOrigin
        public var exposedHeaders: [String]?
        public var maxAge: Int?

        public init(
            allowCredentials: Bool = false,
            allowedHeaders: [String]? = nil,
            allowedMethods: [Request.Method] = [.DELETE, .GET, .HEAD, .PATCH, .POST, .PUT],
            allowedOrigin: AllowedOrigin = .all,
            exposedHeaders: [String]? = nil,
            maxAge: Int? = nil
        ) {
            self.allowCredentials = allowCredentials
            self.allowedHeaders = allowedHeaders
            self.allowedMethods = allowedMethods
            self.allowedOrigin = allowedOrigin
            self.exposedHeaders = exposedHeaders
            self.maxAge = maxAge
        }
    }
}

extension CORSMiddleware.Options {
    public enum AllowedOrigin {
        case all
        case none
        case origins(Set<String>)
        /// Matches the request `Origin` header against a regular expression pattern.
        ///
        /// The pattern is compiled once and cached; an invalid pattern never matches.
        case regex(String)
        case sameAsOrigin

        public func value(from request: Request) -> String {
            guard let origin = request.headers.get(.origin) else { return "" }

            switch self {
            case .all: return "*"
            case .none: return ""
            case .sameAsOrigin: return origin
            case .origins, .regex: return isAllowed(origin) ? origin : "false"
            }
        }

        private func isAllowed(_ origin: String) -> Bool {
            switch self {
            case .origins(let origins): return origins.contains(origin)
            case .regex(let pattern):
                guard let regex = HeaderUtil.cachedRegex(for: pattern) else { return false }
                return regex.firstMatch(in: origin, range: NSRange(location: 0, length: origin.utf16.count)) != nil
            default: return false
            }
        }
    }
}

extension CORSMiddleware {
    private func setAllowCredentialsHeader(response: inout Response) {
        if options.allowCredentials {
            response.headers.set(.init(name: .accessControlAllowCredentials, value: "true"))
        }
    }

    private func setAllowHeadersHeader(request: Request, response: inout Response) {
        if let allowedHeaders = options.allowedHeaders {
            response.headers.set(
                .init(name: .accessControlAllowHeaders, value: allowedHeaders.joined(separator: ","))
            )
        } else if let allowedHeaders = request.headers.get(.accessControlRequestHeaders) {
            response.headers.set(.init(name: .accessControlAllowHeaders, value: allowedHeaders))
        }
    }

    private func setAllowMethodsHeader(response: inout Response) {
        let allowedMethods = options.allowedMethods.map { $0.rawValue }
        response.headers.set(.init(name: .accessControlAllowMethods, value: allowedMethods.joined(separator: ",")))
    }

    private func setAllowOriginHeader(request: Request, response: inout Response) {
        let value = options.allowedOrigin.value(from: request)
        response.headers.set(.init(name: .accessControlAllowOrigin, value: value))

        if case .sameAsOrigin = options.allowedOrigin, !value.isEmpty {
            response.headers.set(.init(name: .vary, value: "origin"))
        }
    }

    private func setExposeHeadersHeader(response: inout Response) {
        if let exposedHeaders = options.exposedHeaders {
            response.headers.set(
                .init(name: .accessControlExposeHeaders, value: exposedHeaders.joined(separator: ","))
            )
        }
    }

    private func setMaxAgeHeader(response: inout Response) {
        if let maxAge = options.maxAge {
            response.headers.set(.init(name: .accessControlMaxAge, value: String(maxAge)))
        }
    }
}

private extension Request {
    var isPreflight: Bool { method == .OPTIONS && headers.get(.accessControlRequestMethod) != nil }
}
