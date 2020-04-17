import class Foundation.JSONSerialization
import struct Foundation.URLComponents

extension Body {
    public var json: ParameterBag<String, Any>? {
        try? JSONSerialization.jsonObject(with: data, options: []) as? ParameterBag<String, Any>
    }

    public var urlEncoded: ParameterBag<String, Any>? {
        if let string = string.removingPercentEncoding?.replacingOccurrences(of: "+", with: " ") {
            var urlComponents = URLComponents()
            urlComponents.query = string

            if let queryItems = urlComponents.queryItems, !queryItems.isEmpty {
                var parameters = ParameterBag<String, Any>()

                for queryItem in queryItems {
                    parameters[queryItem.name] = queryItem.value
                }

                return parameters
            }
        }

        return nil
    }
}
