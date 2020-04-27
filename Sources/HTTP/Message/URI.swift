import struct Foundation.URL
import struct Foundation.URLComponents

public struct URI {
    public static var `default`: Self{ Self(string: "/")! }

    public var scheme: String? { urlComponents?.scheme }
    public var host: String? { urlComponents?.host }
    public var port: Int? { urlComponents?.port }
    public var url: URL? { urlComponents?.url }
    public var string: String? { urlComponents?.string }
    public var path: String? { urlComponents?.path }
    public var query: ParameterBag<String, String>? { getQueryParameters() }

    private var urlComponents: URLComponents?

    public init?(string: String) { urlComponents = URLComponents(string: string) }
}

extension URI {
    private func getQueryParameters() -> ParameterBag<String, String>? {
        if let queryItems = urlComponents?.queryItems, !queryItems.isEmpty {
            var parameters = ParameterBag<String, String>()

            for queryItem in queryItems {
                parameters[queryItem.name] = queryItem.value
            }

            return parameters
        }

        return nil
    }
}

extension URI: Equatable {
    public static func ==(lhs: URI, rhs: URI) -> Bool { lhs.urlComponents == rhs.urlComponents }
}

extension URI: CustomStringConvertible {
    public var description: String { string ?? "" }
}
