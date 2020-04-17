import struct Foundation.URLComponents

public typealias URI = String

extension URI {
    public var parameters: ParameterBag<String, Any>? {
        let urlComponents = URLComponents(string: self)

        if let queryItems = urlComponents?.queryItems, !queryItems.isEmpty {
            var parameters = ParameterBag<String, Any>()

            for queryItem in queryItems {
                parameters[queryItem.name] = queryItem.value
            }

            return parameters
        }

        return nil
    }
}
