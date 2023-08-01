import AnyCodable
import Foundation

/// A convenience API to communicate with `URLComponents`.
public struct URI: Encodable {
    /// A default URI `/`.
    public static var `default`: Self { Self(string: "/")! }

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
    public var query: [String: AnyEncodable] { getQueryItems() }

    /// Fragment.
    public var fragment: String? { urlComponents.fragment }

    private var urlComponents: URLComponents

    /// Initializes a new instance with a URL string.
    ///
    /// - Warning: Returns `nil` if the string is not a valid URL string.
    /// - Parameter string: A URL string.
    public init?(string: String) {
        if let urlComponents = URLComponents(string: string) {
            self.urlComponents = urlComponents
        } else {
            return nil
        }
    }
}

extension URI {
    public func getQuery<T>(_ name: String) -> T? {
        if let value = query[name]?.value {
            if T.self == UUID.self {
                if let uuidString = value as? String {
                    return UUID(uuidString: uuidString) as? T
                }

                return nil
            }

            return value as? T
        }

        return nil
    }

    private func getQueryItems() -> [String: AnyEncodable] {
        if let queryItems = urlComponents.queryItems, !queryItems.isEmpty {
            var parameters = [String: AnyEncodable]()

            for queryItem in queryItems {
                parameters[queryItem.name] = AnyEncodable(queryItem.value)
            }

            return parameters
        }

        return .init()
    }
}

extension URI: Equatable {
    /// See `Equatable`.
    public static func == (lhs: URI, rhs: URI) -> Bool {
        lhs.urlComponents == rhs.urlComponents
    }
}

extension URI: CustomStringConvertible {
    /// See `CustomStringConvertible`.
    public var description: String { string ?? "" }
}
