import Foundation

public typealias URI = String

extension URI {
    public func path(_ handler: @escaping (ParameterBag<String, Any>?) -> Void) {
        let urlComponents = URLComponents(string: self)

        if let queryItems = urlComponents?.queryItems, !queryItems.isEmpty {
            var parameters = ParameterBag<String, Any>()

            for queryItem in queryItems {
                parameters[queryItem.name] = queryItem.value
            }

            handler(parameters)
        } else {
            handler(nil)
        }
    }
}
