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
public struct CORSMiddleware: Middleware, ErrorMiddleware {
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

        return addingCORSHeaders(
            to: encodable,
            request: request
        )
    }

    public func handle(
        request: Request,
        error: Error,
        responder: @escaping ErrorResponder
    ) async throws -> Encodable {
        guard request.headers.get(.origin) != nil else { return try await responder(request, error) }
        return addingCORSHeaders(
            to: try await responder(request, error),
            request: request
        )
    }

    private func addingCORSHeaders(
        to encodable: Encodable,
        request: Request
    ) -> Response {
        var response = encodable as? Response ?? .init("\(encodable)")
        // Resolve the effective Access-Control-Allow-Origin value once so the
        // credentials header can be gated on it (see setAllowCredentialsHeader).
        let originValue = options.allowedOrigin.value(from: request)
        setAllowCredentialsHeader(originValue: originValue, response: &response)
        setAllowHeadersHeader(request: request, response: &response)
        setAllowMethodsHeader(response: &response)
        setAllowOriginHeader(originValue: originValue, response: &response)
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
        /// The pattern is anchored to the full `Origin` value (`^(?:pattern)$`), so it must
        /// match the entire origin rather than any substring. The pattern is compiled once
        /// and cached; an invalid pattern never matches.
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

        /// `true` when the `Access-Control-Allow-Origin` value depends on the request
        /// `Origin` header and the response should therefore carry `Vary: Origin`.
        /// `.all` (`*`) and `.none` (empty) produce a fixed value and do not vary.
        var variesByOrigin: Bool {
            switch self {
            case .all, .none: return false
            case .origins, .regex, .sameAsOrigin: return true
            }
        }

        private func isAllowed(_ origin: String) -> Bool {
            switch self {
            case .origins(let origins): return origins.contains(origin)
            case .regex(let pattern):
                guard let regex = HeaderUtil.cachedRegex(for: "^(?:\(pattern))$") else { return false }
                return regex.firstMatch(
                    in: origin,
                    range: NSRange(location: 0, length: origin.utf16.count)
                ) != nil
            default: return false
            }
        }
    }
}

extension CORSMiddleware {
    private func setAllowCredentialsHeader(
        originValue: String,
        response: inout Response
    ) {
        guard options.allowCredentials else { return }

        // The CORS spec forbids combining credentials with a wildcard origin: a browser
        // rejects `Access-Control-Allow-Credentials: true` alongside
        // `Access-Control-Allow-Origin: *`. Emitting it anyway is a misconfiguration that
        // can mask the real (no-credentials) wildcard behaviour. Only advertise credentials
        // when the origin is a specific value that was matched/reflected for this request —
        // never for `*`, the empty value (`.none`), or the `"false"` not-allowed sentinel.
        guard originValue != "*", originValue != "false", !originValue.isEmpty else { return }

        response.headers.set(
            .init(
                name: .accessControlAllowCredentials,
                value: "true"
            )
        )
    }

    private func setAllowHeadersHeader(
        request: Request,
        response: inout Response
    ) {
        if let allowedHeaders = options.allowedHeaders {
            response.headers.set(
                .init(
                    name: .accessControlAllowHeaders,
                    value: allowedHeaders.joined(separator: ",")
                )
            )
        } else if let allowedHeaders = request.headers.get(.accessControlRequestHeaders) {
            response.headers.set(
                .init(
                    name: .accessControlAllowHeaders,
                    value: allowedHeaders
                )
            )
        }
    }

    private func setAllowMethodsHeader(response: inout Response) {
        let allowedMethods = options.allowedMethods.map { $0.rawValue }
        response.headers.set(
            .init(
                name: .accessControlAllowMethods,
                value: allowedMethods.joined(separator: ",")
            )
        )
    }

    private func setAllowOriginHeader(
        originValue value: String,
        response: inout Response
    ) {
        response.headers.set(.init(name: .accessControlAllowOrigin, value: value))

        // Whenever the `Access-Control-Allow-Origin` value is derived from the request
        // `Origin` (reflected or allowlist/regex-matched), the response varies by origin.
        // Emitting `Vary: Origin` prevents a shared/CDN cache from serving the ACAO header
        // computed for one origin to a request from a different origin (cache poisoning).
        // Static values (`*` for `.all`, empty for `.none`) do not depend on the origin.
        if options.allowedOrigin.variesByOrigin {
            addVaryOrigin(to: &response)
        }
    }

    /// Adds `Origin` to the response `Vary` header without discarding any value a
    /// handler already set (e.g. `Vary: Accept-Encoding`) and without duplicating it.
    private func addVaryOrigin(to response: inout Response) {
        guard let existing = response.headers.get(.vary), !existing.isEmpty else {
            response.headers.set(
                .init(
                    name: .vary,
                    value: "Origin"
                )
            )
            return
        }

        let alreadyPresent = existing
            .split(separator: ",")
            .contains { $0.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare("origin") == .orderedSame }

        if !alreadyPresent {
            response.headers.set(
                .init(
                    name: .vary,
                    value: "\(existing), Origin"
                )
            )
        }
    }

    private func setExposeHeadersHeader(response: inout Response) {
        if let exposedHeaders = options.exposedHeaders {
            response.headers.set(
                .init(
                    name: .accessControlExposeHeaders,
                    value: exposedHeaders.joined(separator: ",")
                )
            )
        }
    }

    private func setMaxAgeHeader(response: inout Response) {
        if let maxAge = options.maxAge {
            response.headers.set(
                .init(
                    name: .accessControlMaxAge,
                    value: String(maxAge)
                )
            )
        }
    }
}

private extension Request {
    var isPreflight: Bool { method == .OPTIONS && headers.get(.accessControlRequestMethod) != nil }
}
