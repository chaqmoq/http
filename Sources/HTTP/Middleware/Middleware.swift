public protocol Middleware {
    func handle(request: Request, nextHandler: @escaping (Request) async -> Response) async -> Response
}
