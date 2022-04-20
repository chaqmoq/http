public protocol Middleware {
    func handle(
        request: Request,
        nextHandler: @escaping (Request) async throws -> Response
    ) async throws -> Response
}
