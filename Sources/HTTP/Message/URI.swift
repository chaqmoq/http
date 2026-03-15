import AnyCodable
import Foundation

/// A convenience API to communicate with `URLComponents`.
public struct URI: Encodable, Sendable {
    /// A default URI `/`.
    public static var `default`: Self { Self("/")! }

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
