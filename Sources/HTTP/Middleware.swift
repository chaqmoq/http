public protocol Middleware {
    func handle(request: inout Request, response: inout Response, nextHandler: @escaping () -> Void)
}
