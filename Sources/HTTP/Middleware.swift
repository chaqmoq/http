public protocol Middleware {
    typealias RequestHandler = () -> Void
    typealias ResponseHandler = () -> Void

    func handleRequest(_ request: inout Request, nextHandler: @escaping RequestHandler) -> Any
    func handleResponse(_ response: inout Response, nextHandler: @escaping ResponseHandler) -> Any
}

public extension Middleware {
    func handleRequest(_ request: inout Request, nextHandler: @escaping RequestHandler) -> Any {
        nextHandler()
    }

    func handleResponse(_ response: inout Response, nextHandler: @escaping ResponseHandler) -> Any {
        nextHandler()
    }
}
