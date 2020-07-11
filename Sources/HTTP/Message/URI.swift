import Foundation

public struct URI {
    public static var `default`: Self{ Self(string: "/")! }

    public var scheme: String? { urlComponents?.scheme }
    public var host: String? { urlComponents?.host }
    public var port: Int? { urlComponents?.port }
    public var url: URL? { urlComponents?.url }
    public var string: String? { urlComponents?.string }
    public var path: String? { urlComponents?.path }
    public var query: Parameters<String, String>? { getQueryParameters() }
    private var urlComponents: URLComponents?

    public init?(string: String) {
        urlComponents = URLComponents(string: string)
        if urlComponents == nil { return nil }
    }
}

extension URI {
    private func getQueryParameters() -> Parameters<String, String>? {
        if let queryItems = urlComponents?.queryItems, !queryItems.isEmpty {
            var parameters = Parameters<String, String>()
            for queryItem in queryItems { parameters[queryItem.name] = queryItem.value }

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
