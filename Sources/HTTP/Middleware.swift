public protocol Middleware {
    func handle(request: Request, nextHandler: @escaping (Request) -> Response) -> Response
}
