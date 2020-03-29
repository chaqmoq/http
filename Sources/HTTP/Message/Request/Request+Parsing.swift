import Foundation

extension Request {
    mutating func parseQuery() {
        let urlComponents = URLComponents(string: uri)

        if let queryItems = urlComponents?.queryItems, !queryItems.isEmpty {
            queryParameters = .init()

            for queryItem in queryItems {
                queryParameters?[queryItem.name] = queryItem.value
            }
        }
    }

    mutating func parseBody() {
        guard let contentType = headers[.contentType] else { return }

        if contentType.hasPrefix("application/x-www-form-urlencoded") {
            bodyParameters = parseURLEncodedBody()
        } else if contentType.hasPrefix("application/json") {
            bodyParameters = parseJSONBody()
        }
    }
}

extension Request {
    private func parseURLEncodedBody() -> ParameterBag<String, Any>? {
        if let string = body.string?.removingPercentEncoding?.replacingOccurrences(of: "+", with: " ") {
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

    private func parseJSONBody() -> ParameterBag<String, Any>? {
        if let data = body.data {
            return try? JSONSerialization.jsonObject(with: data, options: []) as? ParameterBag<String, Any>
        }

        return nil
    }
}
