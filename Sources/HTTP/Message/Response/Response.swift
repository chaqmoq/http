import Foundation

/// Represents an outbound HTTP response sent by the server.
///
/// `Response` is a value type that carries the complete state of an HTTP response,
/// including its status, version, headers, cookies, and body. The `Content-Length`
/// header is kept in sync automatically whenever the body is changed.
///
/// ```swift
/// server.onReceive = { request in
///     var response = Response("Hello!", status: .ok)
///     response.setCookie(Cookie(name: "sessionId", value: "abc123"))
///     return response
/// }
/// ```
public struct Response: Encodable, Message, Sendable {
    /// The HTTP version used for this response.
    public var version: Version

    /// The HTTP status code and reason phrase.
    public var status: Status

    /// The HTTP headers to include in the response.
    ///
    /// Setting this property automatically re-parses cookies when a `Set-Cookie` header changes.
    public var headers: Headers {
        didSet {
            // Only re-parse cookies when a Set-Cookie header value actually changed.
            // Other header mutations (e.g. Content-Length, Content-Type) previously
            // triggered a full cookie re-parse unnecessarily.
            if headers.values(for: .setCookie) != oldValue.values(for: .setCookie) {
                setCookies()
            }
        }
    }

    /// Cookies derived from all `Set-Cookie` response headers.
    public var cookies: Set<Cookie> { mutableCookies }
    private var mutableCookies = Set<Cookie>()

    /// The response body.
    ///
    /// Setting this property automatically updates the `Content-Length` header.
    public var body: Body {
        didSet { setContentLengthHeader() }
    }

    /// Creates a response with a ``Body`` payload.
    ///
    /// - Parameters:
    ///   - body: The response body. Defaults to an empty body.
    ///   - status: The HTTP status code. Defaults to `.ok`.
    ///   - headers: The response headers. Defaults to empty.
    ///   - version: The HTTP version. Defaults to HTTP/1.1.
    public init(
        _ body: Body = .init(),
        status: Status = .ok,
        headers: Headers = .init(),
        version: Version = .init()
    ) {
        self.version = version
        self.status = status
        self.headers = headers
        self.body = body

        setContentLengthHeader()
        setCookies()
    }

    /// Creates a response with a UTF-8 string body.
    ///
    /// - Parameters:
    ///   - string: The plain-text response body.
    ///   - status: The HTTP status code. Defaults to `.ok`.
    ///   - headers: The response headers. Defaults to empty.
    ///   - version: The HTTP version. Defaults to HTTP/1.1.
    public init(
        _ string: String,
        status: Status = .ok,
        headers: Headers = .init(),
        version: Version = .init()
    ) {
        self.init(.init(string: string), status: status, headers: headers, version: version)
    }

    /// Creates a response with a `Data` body.
    ///
    /// - Parameters:
    ///   - data: The raw response body data.
    ///   - status: The HTTP status code. Defaults to `.ok`.
    ///   - headers: The response headers. Defaults to empty.
    ///   - version: The HTTP version. Defaults to HTTP/1.1.
    public init(
        _ data: Data,
        status: Status = .ok,
        headers: Headers = .init(),
        version: Version = .init()
    ) {
        self.init(.init(data: data), status: status, headers: headers, version: version)
    }
}

extension Response {
    /// Returns `true` if a `Set-Cookie` header for a cookie with the given name exists.
    ///
    /// - Parameter name: The cookie name to look up (case-insensitive).
    public func hasCookie(named name: String) -> Bool {
        let lowercased = name.lowercased()
        return mutableCookies.contains(where: { $0.name.lowercased() == lowercased })
    }

    /// Adds a `Set-Cookie` header for `cookie`, replacing any existing header with the same name.
    ///
    /// - Parameter cookie: The cookie to set in the response.
    public mutating func setCookie(_ cookie: Cookie) {
        let headerName = HeaderName.setCookie.rawValue
        // Append "=" so that a cookie named "session" does not accidentally match
        // a cookie named "sessionId" whose Set-Cookie value starts with "sessionid=".
        let prefix = cookie.name.lowercased() + "="

        if let index = headers.firstIndex(where: {
            $0.name == headerName &&
            $0.value.lowercased().hasPrefix(prefix)
        }) {
            headers[index] = Header(name: headerName, value: "\(cookie)")
        } else {
            headers.add(.init(name: .setCookie, value: "\(cookie)"))
        }
    }

    mutating func setCookies() {
        mutableCookies.removeAll()
        let headerLines = headers.values(for: .setCookie)
        guard !headerLines.isEmpty else { return }

        for headerLine in headerLines {
            var parameters = headerLine.components(separatedBy: ";").filter { $0 != "" }

            if let firstParameter = parameters.first {
                parameters.removeFirst()
                let nameValue = firstParameter.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")

                if let name = nameValue.first, let value = nameValue.last, nameValue.count == 2 {
                    var cookie = Cookie(name: name, value: value)
                    var cookieExists = false

                    if let index = mutableCookies.firstIndex(of: cookie) {
                        cookie = mutableCookies[index]
                        cookieExists = true
                    }

                    for parameter in parameters {
                        let nameValue = parameter.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")

                        if let name = nameValue.first?.lowercased(),
                           let optionName = Cookie.OptionName(rawValue: name) {
                            let count = nameValue.count

                            switch optionName {
                            case .expires:
                                if let value = nameValue.last, count == 2 {
                                    cookie.expires = Date(rfc1123: value)
                                }
                            case .maxAge:
                                if let value = nameValue.last, count == 2 {
                                    cookie.maxAge = Int(value)
                                }
                            case .domain:
                                if let value = nameValue.last, count == 2 {
                                    cookie.domain = value
                                }
                            case .path:
                                if let value = nameValue.last, count == 2 {
                                    cookie.path = value
                                }
                            case .isSecure:
                                cookie.isSecure = true
                            case .isHTTPOnly:
                                cookie.isHTTPOnly = true
                            case .sameSite:
                                if let value = nameValue.last?.lowercased(),
                                   let optionValue = Cookie.SameSite(rawValue: value) {
                                    cookie.sameSite = optionValue
                                }
                            }
                        }
                    }

                    if cookieExists {
                        mutableCookies.update(with: cookie)
                    } else {
                        mutableCookies.insert(cookie)
                    }
                }
            }
        }
    }

    /// Removes the `Set-Cookie` header for the cookie with the given name.
    ///
    /// Does nothing if no matching `Set-Cookie` header is found.
    ///
    /// - Parameter name: The name of the cookie whose `Set-Cookie` header should be removed.
    public mutating func clearCookie(named name: String) {
        let headerName = HeaderName.setCookie.rawValue
        let prefix = name.lowercased() + "="

        if let index = headers.firstIndex(where: {
            $0.name == headerName && $0.value.lowercased().hasPrefix(prefix)
        }) {
            headers.remove(at: index)
        }
    }

    /// Removes all `Set-Cookie` headers from the response.
    public mutating func clearCookies() {
        headers.remove(.setCookie)
    }
}
