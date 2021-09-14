import Foundation

public struct Cookie: Encodable {
    public static let path: String = "/"

    public let name: String
    public var value: String
    public var expires: Date?
    public var maxAge: Int?
    public var domain: String?
    public var path: String?
    public var isSecure: Bool
    public var isHTTPOnly: Bool
    public var sameSite: SameSite?

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
    public enum OptionName: String, CaseIterable {
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
    public enum SameSite: String, CaseIterable, Encodable {
        case strict
        case lax
        case none
    }
}

extension Cookie: Hashable {
    public static func == (lhs: Cookie, rhs: Cookie) -> Bool { lhs.name == rhs.name }
    public func hash(into hasher: inout Hasher) { hasher.combine(name) }
}

extension Cookie: CustomStringConvertible {
    public var description: String {
        var description = "\(name)=\(value)"
        if let expires = expires { description += "; \(OptionName.expires.rawValue)=\(expires.rfc1123)" }
        if let maxAge = maxAge { description += "; \(OptionName.maxAge.rawValue)=\(maxAge)" }
        if let domain = domain { description += "; \(OptionName.domain.rawValue)=\(domain)" }
        if let path = path { description += "; \(OptionName.path.rawValue)=\(path)" }
        if isSecure { description += "; \(OptionName.isSecure.rawValue)" }
        if isHTTPOnly { description += "; \(OptionName.isHTTPOnly.rawValue)" }
        if let sameSite = sameSite { description += "; \(OptionName.sameSite.rawValue)=\(sameSite.rawValue)" }

        return description
    }
}
