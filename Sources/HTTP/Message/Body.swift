import Foundation

public struct Body {
    public var bytes: [UInt8] { content }
    public var data: Data { string.data(using: .utf8) ?? .init() }
    public var string: String { String(bytes: content, encoding: .utf8) ?? "" }
    public var count: Int { content.count }
    public var isEmpty: Bool { content.isEmpty }
    private var content: [UInt8]

    public init(bytes: [UInt8] = .init()) {
        content = bytes
    }

    public init(data: Data) {
        content = [UInt8](data)
    }

    public init(string: String) {
        content = [UInt8](string.utf8)
    }
}

extension Body {
    public mutating func append(bytes: [UInt8]) {
        content.append(contentsOf: bytes)
    }

    public mutating func append(data: Data) {
        content.append(contentsOf: [UInt8](data))
    }

    public mutating func append(string: String) {
        content.append(contentsOf: [UInt8](string.utf8))
    }
}

extension Body {
    public func json(_ handler: @escaping (ParameterBag<String, Any>?) -> Void) {
        let parameters = try? JSONSerialization.jsonObject(with: data, options: []) as? ParameterBag<String, Any>
        handler(parameters)
    }

    public func urlEncoded(_ handler: @escaping (ParameterBag<String, Any>?) -> Void) {
        if let string = string.removingPercentEncoding?.replacingOccurrences(of: "+", with: " ") {
            var urlComponents = URLComponents()
            urlComponents.query = string

            if let queryItems = urlComponents.queryItems, !queryItems.isEmpty {
                var parameters = ParameterBag<String, Any>()

                for queryItem in queryItems {
                    parameters[queryItem.name] = queryItem.value
                }

                handler(parameters)
            } else {
                handler(nil)
            }
        } else {
            handler(nil)
        }
    }
}

extension Body: CustomStringConvertible {
    public var description: String { string }
}
