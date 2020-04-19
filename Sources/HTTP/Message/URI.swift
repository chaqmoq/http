import struct Foundation.URLComponents

public struct URI {
    public static var `default`: Self{ Self(string: "/")! }

    public var scheme: String? { urlComponents?.scheme }
    public var host: String? { urlComponents?.host }
    public var port: Int? { urlComponents?.port }
    public var path: String? { urlComponents?.path }

    public var query: ParameterBag<String, Any>? {
        if let queryItems = urlComponents?.queryItems, !queryItems.isEmpty {
            var parameters = ParameterBag<String, Any>()

            for queryItem in queryItems {
                parameters[queryItem.name] = queryItem.value
            }

            return parameters
        }

        return nil
    }

    private var urlComponents: URLComponents?

    public init?(string: String) {
        urlComponents = URLComponents(string: string)
    }
}

extension URI: Equatable {
    public static func == (lhs: URI, rhs: URI) -> Bool {
        lhs.urlComponents == rhs.urlComponents
    }
}

extension URI: CustomStringConvertible {
    public var description: String { urlComponents?.string ?? "" }
}
