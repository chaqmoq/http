import Foundation

/// Represents an HTTP cookie as described in RFC 6265.
///
/// Cookies with names prefixed by `__Host-` automatically have their `domain` cleared,
/// their `path` set to `/`, and `isSecure` forced to `true` in accordance with the
/// cookie prefix specification. Cookies prefixed by `__Secure-` also force `isSecure`.
///
/// Two cookies are considered equal (and share the same hash value) when their `name` matches,
/// enabling use in `Set<Cookie>` to track one cookie per name.
///
/// ```swift
/// var cookie = Cookie(name: "sessionId", value: "abc123", isHTTPOnly: true, isSecure: true)
/// response.setCookie(cookie)
/// ```
public struct Cookie: Encodable, Sendable {
    /// The default path value applied to cookies with the `__Host-` prefix.
    public static let path: String = "/"

    /// The cookie name. Immutable after creation.
    public let name: String

    /// The cookie value.
    public var value: String

    /// The expiry date of the cookie, serialised using the RFC 1123 format.
    public var expires: Date?

    /// The maximum age of the cookie in seconds (takes precedence over `expires`).
    public var maxAge: Int?

    /// The domain to which the cookie is scoped.
    public var domain: String?

    /// The URL path to which the cookie is scoped.
    public var path: String?

    /// When `true` the cookie is only sent over HTTPS.
    public var isSecure: Bool

    /// When `true` the cookie is inaccessible to JavaScript (`HttpOnly` flag).
    public var isHTTPOnly: Bool

    /// Controls cross-site request behaviour (`SameSite` attribute).
    public var sameSite: SameSite?

    /// Initializes a new `Cookie`.
    ///
    /// - Parameters:
    ///   - name: The cookie name.
    ///   - value: The cookie value.
    ///   - expires: An optional expiry date.
    ///   - maxAge: An optional max-age in seconds.
    ///   - domain: An optional domain scope.
    ///   - path: An optional path scope.
    ///   - isSecure: Whether the `Secure` flag should be set. Defaults to `false`.
    ///   - isHTTPOnly: Whether the `HttpOnly` flag should be set. Defaults to `false`.
    ///   - sameSite: An optional `SameSite` attribute value.
    public init(
        name: String,
        value: String,
        expires: Date? = nil,
        maxAge: Int? = nil,
        domain: String? = nil,
        path: String? = nil,
        isSecure: Bool = false,
        isHTTPOnly: Bool = false,
        sameSite: SameSite? = nil
    ) {
        self.name = name
        self.value = value
        self.expires = expires
        self.maxAge = maxAge
        self.domain = domain
        self.path = path
        self.isSecure = isSecure
        self.isHTTPOnly = isHTTPOnly
        self.sameSite = sameSite

        let lowercasedName = self.name.lowercased()

        if lowercasedName.hasPrefix("__host-") {
            self.domain = nil
            self.path = Cookie.path
            self.isSecure = true
        }

        if lowercasedName.hasPrefix("__secure-") {
            self.isSecure = true
        }
    }
}

extension Cookie {
    /// The set of recognised cookie attribute names used during serialisation and parsing.
    public enum OptionName: String, CaseIterable, Sendable {
        case expires
        case maxAge = "max-age"
        case domain
        case path
        case isSecure = "secure"
        case isHTTPOnly = "httponly"
        case sameSite = "samesite"
    }
}

extension Cookie {
    /// The `SameSite` cookie attribute controls whether the browser sends the cookie with
    /// cross-site requests.
    public enum SameSite: String, CaseIterable, Encodable, Sendable {
        /// The cookie is only sent to first-party contexts.
        case strict
        /// The cookie is sent with top-level navigations and same-site requests.
        case lax
        /// The cookie is sent with all requests. Requires `isSecure = true`.
        case none
    }
}

extension Cookie: Hashable {
    /// Two cookies are equal when their `name` properties match (case-sensitive).
    ///
    /// This matches the browser model where a cookie jar holds at most one value per name,
    /// and allows `Set<Cookie>` to deduplicate by name.
    public static func == (lhs: Cookie, rhs: Cookie) -> Bool {
        lhs.name == rhs.name
    }

    /// Hashes the cookie using only its `name`, consistent with ``==(_:_:)``.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

extension Cookie: CustomStringConvertible {
    /// A `Set-Cookie` header value string for this cookie, e.g.
    /// `"id=1; max-age=3600; path=/; secure; httponly; samesite=lax"`.
    public var description: String {
        var content = "\(name)=\(value)"

        if let expires = expires {
            content += "; \(OptionName.expires.rawValue)=\(expires.rfc1123)"
        }

        if let maxAge = maxAge {
            content += "; \(OptionName.maxAge.rawValue)=\(maxAge)"
        }

        if let domain = domain {
            content += "; \(OptionName.domain.rawValue)=\(domain)"
        }

        if let path = path {
            content += "; \(OptionName.path.rawValue)=\(path)"
        }

        if isSecure {
            content += "; \(OptionName.isSecure.rawValue)"
        }

        if isHTTPOnly {
            content += "; \(OptionName.isHTTPOnly.rawValue)"
        }

        if let sameSite = sameSite {
            content += "; \(OptionName.sameSite.rawValue)=\(sameSite.rawValue)"
        }

        return content
    }
}
