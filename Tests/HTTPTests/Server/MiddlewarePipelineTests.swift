import AsyncHTTPClient
@testable import HTTP
import NIO
import XCTest

private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

/// Tests for the full middleware pipeline executed through the live server,
/// covering chained middleware, error middleware, and middleware mutation of requests.
final class MiddlewarePipelineTests: XCTestCase, @unchecked Sendable {
    var client: HTTPClient!
    var server: Server!

    override func setUp() {
        super.setUp()
        client = HTTPClient(eventLoopGroupProvider: .singleton)
        server = Server(configuration: .init(numberOfThreads: 1))
    }

    // MARK: - Middleware chain executes in order

    func testMiddlewareChainExecutesInOrder() {
        let order = Box<[Int]>([])

        struct OrderMiddleware: Middleware {
            let index: Int
            let record: @Sendable (Int) -> Void

            func handle(request: Request, responder: @escaping Responder) async throws -> any Encodable & Sendable {
                record(index)

                return try await responder(request)
            }
        }

        server.middleware = [
            OrderMiddleware(index: 1, record: { order.value.append($0) }),
            OrderMiddleware(index: 2, record: { order.value.append($0) }),
            OrderMiddleware(index: 3, record: { order.value.append($0) })
        ]

        execute { result in
            switch result {
            case .success:
                XCTAssertEqual(order.value, [1, 2, 3])
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Middleware can short-circuit the chain

    func testMiddlewareCanShortCircuit() {
        let handlerCalled = Box(false)

        struct ShortCircuitMiddleware: Middleware {
            func handle(request: Request, responder: @escaping Responder) async throws -> any Encodable & Sendable {
                Response("short-circuited", status: .forbidden)
            }
        }

        server.middleware = [ShortCircuitMiddleware()]
        server.onReceive = { _ in
            handlerCalled.value = true

            return Response("should not reach here")
        }

        execute(customHandler: false) { result in
            switch result {
            case .success(let response):
                XCTAssertFalse(handlerCalled.value)
                XCTAssertEqual(response.status, .forbidden)
                XCTAssertEqual(response.body.string, "short-circuited")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Middleware can mutate the request

    func testMiddlewareCanMutateRequest() {
        let receivedMethod = Box<Request.Method?>(nil)

        struct MethodOverride: Middleware {
            func handle(request: Request, responder: @escaping Responder) async throws -> any Encodable & Sendable {
                var mutated = request
                mutated.method = .DELETE

                return try await responder(mutated)
            }
        }

        server.middleware = [MethodOverride()]
        server.onReceive = { request in
            receivedMethod.value = request.method

            return Response()
        }

        execute(customHandler: false) { result in
            switch result {
            case .success:
                XCTAssertEqual(receivedMethod.value, .DELETE)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Error middleware receives chained errors

    func testErrorMiddlewareChainIsTraversed() {
        let chainOrder = Box<[Int]>([])

        struct ChainedErrorMiddleware: ErrorMiddleware {
            let index: Int
            let record: @Sendable (Int) -> Void

            func handle(
                request: Request,
                error: Error,
                responder: @escaping ErrorResponder
            ) async throws -> any Encodable & Sendable {
                record(index)

                return try await responder(request, error)
            }
        }

        struct TerminalErrorMiddleware: ErrorMiddleware {
            func handle(
                request: Request,
                error: Error,
                responder: @escaping ErrorResponder
            ) async throws -> any Encodable & Sendable {
                Response("error handled", status: .badRequest)
            }
        }

        struct TestError: Error {}

        server.middleware = []
        server.errorMiddleware = [
            ChainedErrorMiddleware(index: 1, record: { chainOrder.value.append($0) }),
            ChainedErrorMiddleware(index: 2, record: { chainOrder.value.append($0) }),
            TerminalErrorMiddleware()
        ]
        server.onReceive = { _ in throw TestError() }

        execute(customHandler: false) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(chainOrder.value, [1, 2])
                XCTAssertEqual(response.status, .badRequest)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - No error middleware falls back to 500

    func testNoErrorMiddlewareFallsBackTo500() {
        struct TestError: Error {}
        server.errorMiddleware = []
        server.onReceive = { _ in throw TestError() }

        execute(customHandler: false) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.status, .internalServerError)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
}

// MARK: - Helper

extension MiddlewarePipelineTests {
    func execute(
        customHandler: Bool = true,
        responseHandler: @escaping @Sendable (Result<Response, Error>) -> Void
    ) {
        let uri = URI(server.configuration.socketAddress)!

        server.onStart = { [weak self] _ in
            guard let self else { return }

            let request = try! HTTPClient.Request(url: uri.string!, method: .GET)

            client.execute(request: request).whenComplete { [weak self] result in
                switch result {
                case .failure(let error):
                    responseHandler(.failure(error))
                case .success(let httpResponse):
                    let status = Response.Status(rawValue: Int(httpResponse.status.code)) ?? .ok
                    var headers = Headers()

                    for header in httpResponse.headers {
                        headers.set(.init(name: header.name, value: header.value))
                    }

                    let body: Body
                    if let buf = httpResponse.body,
                       let bytes = buf.getBytes(at: 0, length: buf.readableBytes) {
                        body = Body(bytes: bytes)
                    } else {
                        body = Body()
                    }

                    responseHandler(.success(Response(body, status: status, headers: headers)))
                }

                DispatchQueue.global().asyncAfter(deadline: .now()) { [weak self] in
                    try! self?.client.syncShutdown()
                    try! self?.server.stop()
                }
            }
        }

        if customHandler {
            server.onReceive = { _ in Response() }
        }

        try! server.start()
    }
}
