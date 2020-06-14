import Foundation

public struct Cookie {
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
    }
}

extension Cookie {
    public enum OptionKey: String {
        case expires = "Expires"
        case maxAge = "Max-Age"
        case domain = "Domain"
        case path = "Path"
        case isSecure = "Secure"
        case isHTTPOnly = "HttpOnly"
        case sameSite = "SameSite"
    }
}

extension Cookie {
    public enum SameSite: String {
        case strict = "Strict"
        case lax = "Lax"
        case none = "None"
    }
}

extension Cookie: Hashable {
    public static func ==(lhs: Cookie, rhs: Cookie) -> Bool { lhs.name == rhs.name }
    public func hash(into hasher: inout Hasher) { hasher.combine(name) }
}

extension Cookie: CustomStringConvertible {
    public var description: String {
        var description = "\(name)=\(value)"
        if let expires = expires { description += "; \(OptionKey.expires.rawValue)=\(expires.rfc1123)" }
        if let maxAge = maxAge { description += "; \(OptionKey.maxAge.rawValue)=\(maxAge)" }
        if let domain = domain { description += "; \(OptionKey.domain.rawValue)=\(domain)" }
        if let path = path { description += "; \(OptionKey.path.rawValue)=\(path)" }
        if isSecure { description += "; \(OptionKey.isSecure.rawValue)" }
        if isHTTPOnly { description += "; \(OptionKey.isHTTPOnly.rawValue)" }
        if let sameSite = sameSite { description += "; \(OptionKey.sameSite.rawValue)=\(sameSite.rawValue)" }

        return description
    }
}

extension Date {
    var rfc1123: String { dateFormatter.string(from: self) }
    var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"

        return dateFormatter
    }

    init(rfc1123: String) {
        self = Date()
        if let date = dateFormatter.date(from: rfc1123) { self = date }
    }
}
