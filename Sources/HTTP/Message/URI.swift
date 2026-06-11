import Foundation

/// A convenience API to communicate with `URLComponents`.
public struct URI: Encodable, Sendable {
    /// A default URI `/`.
    // `static let` ensures the URLComponents parse happens once, not on every access.
    public static let `default`: Self = Self("/")!

    /// A `scheme` subcomponent of `URLComponents`.
    public var scheme: String? { urlComponents.scheme }

    /// A `host` subcomponent of `URLComponents`.
    public var host: String? { urlComponents.host }

    /// A `port` subcomponent of `URLComponents`.
    public var port: Int? { urlComponents.port }

    /// A `url` subcomponent of `URLComponents`.
    public var url: URL? { urlComponents.url }

    /// A URL string  of `URLComponents`.
    public var string: String? { urlComponents.string }

    /// A `path` subcomponent of `URLComponents`.
    public var path: String? { urlComponents.path }

    /// Query parameters.
    public private(set) var query = [String: String]()

    /// Fragment.
    public var fragment: String? { urlComponents.fragment }

    private var urlComponents: URLComponents

    /// Initializes a new instance with a URL string.
    ///
    /// - Warning: Returns `nil` if the string is not a valid URL string.
    /// - Parameter string: A URL string.
    public init?(_ string: String) {
        if let urlComponents = URLComponents(string: string) {
            self.urlComponents = urlComponents
            query = getQueryItems()
        } else {
            return nil
        }
    }
}

extension URI {
    /// Validates a raw HTTP request target (RFC 9112 §3.2) before URL parsing.
    ///
    /// `URLComponents` cannot be relied on to reject malformed targets — its parser
    /// grew increasingly lenient across Foundation versions (newer releases
    /// percent-encode invalid characters instead of failing). This check provides a
    /// deterministic, platform-independent floor. It rejects targets that are empty,
    /// contain control characters (0x00–0x1F, 0x7F) or raw spaces, or contain an
    /// invalid percent-escape (`%` not followed by two hex digits).
    ///
    /// - Parameter target: The raw request target from the request line.
    /// - Returns: `true` when the target is structurally sound enough to parse.
    public static func isValidRequestTarget(_ target: String) -> Bool {
        guard !target.isEmpty else { return false }

        let bytes = Array(target.utf8)
        var index = 0

        func isHexDigit(_ byte: UInt8) -> Bool {
            (0x30...0x39).contains(byte)    // 0-9
                || (0x41...0x46).contains(byte) // A-F
                || (0x61...0x66).contains(byte) // a-f
        }

        while index < bytes.count {
            let byte = bytes[index]

            // Control characters and space terminate or split the request line —
            // they can never legally appear raw inside a request target.
            if byte <= 0x20 || byte == 0x7F {
                return false
            }

            // A percent sign must introduce a valid two-hex-digit escape.
            if byte == UInt8(ascii: "%") {
                guard index + 2 < bytes.count,
                      isHexDigit(bytes[index + 1]),
                      isHexDigit(bytes[index + 2]) else {
                    return false
                }
                index += 3
                continue
            }

            index += 1
        }

        return true
    }
}

extension URI {
    /// Returns a typed query parameter by name.
    ///
    /// The raw string value stored in ``query`` is converted to the inferred type `T`.
    /// Supported types: `String`, `Character`, `Bool`, `Int`/`Int8`/`Int16`/`Int32`/`Int64`,
    /// `UInt`/`UInt8`/`UInt16`/`UInt32`/`UInt64`, `Float`, `Double`, `URL`, and `UUID`.
    ///
    /// ```swift
    /// let uri = URI("/search?page=2&active=true")!
    /// let page: Int? = uri.getQuery("page")     // 2
    /// let active: Bool? = uri.getQuery("active") // true
    /// ```
    ///
    /// - Parameter name: The query parameter key.
    /// - Returns: The parameter value converted to `T`, or `nil` if absent or conversion fails.
    public func getQuery<T>(_ name: String) -> T? {
        if let value = query[name] {
            let type = T.self

            if type == String.self {
                return value as? T
            } else if type == Character.self {
                return Character(value) as? T
            } else if type == Bool.self {
                return Bool(value) as? T
            } else if type == Int.self {
                return Int(value) as? T
            } else if type == Int8.self {
                return Int8(value) as? T
            } else if type == Int16.self {
                return Int16(value) as? T
            } else if type == Int32.self {
                return Int32(value) as? T
            } else if type == Int64.self {
                return Int64(value) as? T
            } else if type == UInt.self {
                return UInt(value) as? T
            } else if type == UInt8.self {
                return UInt8(value) as? T
            } else if type == UInt16.self {
                return UInt16(value) as? T
            } else if type == UInt32.self {
                return UInt32(value) as? T
            } else if type == UInt64.self {
                return UInt64(value) as? T
            } else if type == Float.self {
                return Float(value) as? T
            } else if type == Double.self {
                return Double(value) as? T
            } else if type == URL.self {
                return URL(string: value) as? T
            } else if type == UUID.self {
                return UUID(uuidString: value) as? T
            }
        }

        return nil
    }

    private func getQueryItems() -> [String: String] {
        var parameters = [String: String]()

        if let queryItems = urlComponents.queryItems {
            for queryItem in queryItems {
                parameters[queryItem.name] = queryItem.value
            }
        }

        return parameters
    }
}

extension URI: Equatable {
    /// Returns `true` when both URIs represent the same URL components.
    ///
    /// Comparison delegates to `URLComponents` equality, which checks scheme, host, port,
    /// path, query, and fragment.
    ///
    /// - Parameters:
    ///   - lhs: A URI value.
    ///   - rhs: Another URI value.
    /// - Returns: `true` if both URIs have identical `URLComponents`.
    public static func == (lhs: URI, rhs: URI) -> Bool {
        lhs.urlComponents == rhs.urlComponents
    }
}

extension URI: CustomStringConvertible {
    /// The URI as a percent-encoded URL string, e.g. `"/search?q=hello%20world"`.
    ///
    /// Returns an empty string when `URLComponents` cannot produce a valid string
    /// representation (which should not occur for well-formed URIs).
    public var description: String { string ?? "" }
}
