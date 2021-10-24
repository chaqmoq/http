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

    /// Path parameters.
    public var parameters: [String: AnyEncodable] { mutableParameters }

    private var mutableParameters: [String: AnyEncodable] = .init()

    /// Query parameters.
    public var query: [String: AnyEncodable]? { getQueryParameters() }

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
    public mutating func setParameter(_ name: String, value: Any?) {
        mutableParameters[name] = AnyEncodable(value)
    }

    public func getParameter<T>(_ name: String) -> T? {
        parameters[name]?.value as? T
    }

    public func getQueryParameter<T>(_ name: String) -> T? {
        query?[name]?.value as? T
    }

    private func getQueryParameters() -> [String: AnyEncodable]? {
        if let queryItems = urlComponents.queryItems, !queryItems.isEmpty {
            var parameters = [String: AnyEncodable]()
            for queryItem in queryItems { parameters[queryItem.name] = AnyEncodable(queryItem.value) }

            return parameters
        }

        return nil
    }
}

extension URI: Equatable {
    /// See `Equatable`.
    public static func == (lhs: URI, rhs: URI) -> Bool { lhs.urlComponents == rhs.urlComponents }
}

extension URI: CustomStringConvertible {
    /// See `CustomStringConvertible`.
    public var description: String { string ?? "" }
}
