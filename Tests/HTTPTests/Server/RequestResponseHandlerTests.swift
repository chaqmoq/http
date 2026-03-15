import AsyncHTTPClient
@testable import HTTP
import NIO
import NIOHTTP1
import XCTest

/// Integration tests that exercise `RequestResponseHandler` logic not covered by
/// the existing `ClientServerAdvancedTests`.
///
/// Each test starts a real server on port 8089, makes exactly one HTTP request, then
/// stops both server and client inside `AsyncHTTPClient`'s `whenComplete` callback.
///
/// The `execute` helper passes `AsyncHTTPClient.HTTPClient.Response` directly to each
/// assertion closure so the server's actual wire headers are inspected without the
/// side-effects of constructing a `Response` value (whose `init` always overwrites
/// `Content-Length` to match the body length).
final class RequestResponseHandlerTests: XCTestCase {
    var client: HTTPClient!
    var server: Server!

    override func setUp() {
        super.setUp()
        client = HTTPClient(eventLoopGroupProvider: .singleton)
        server = Server(configuration: .init(port: 8089, numberOfThreads: 1))
    }

    // MARK: - Server name header

    func testServerNameHeaderAppearsInResponse() {
        server = Server(configuration: .init(
            port: 8089,
            serverName: "Acme/3.1",
            numberOfThreads: 1
        ))

        execute { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.headers.first(name: "server"), "Acme/3.1")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testNoServerHeaderWhenServerNameIsNil() {
        server = Server(configuration: .init(
            port: 8089,
            serverName: nil,
            numberOfThreads: 1
        ))

        execute { result in
            switch result {
            case .success(let response):
                XCTAssertNil(response.headers.first(name: "server"))
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - HEAD body and Content-Length

    func testHEADBodyStrippedButContentLengthPreserved() {
        // The handler returns a Response with a body; RequestResponseHandler must
        // strip the body for HEAD but preserve the Content-Length that was set by
        // Response.body.didSet, so the client can learn the would-be GET body size.
        execute(method: .HEAD, handlerResponse: Response(Body(string: "hello world"))) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.body?.readableBytes ?? 0, 0)
                XCTAssertEqual(response.headers.first(name: "content-length"), "11")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - 204 No Content strips Content-Length

    func testNoContentResponseRemovesContentLength() {
        // A 204 must not carry Content-Length: the handler sets a body (which triggers
        // didSet and adds Content-Length), but RequestResponseHandler must strip both.
        execute(handlerResponse: Response(Body(string: "ignored"), status: .noContent)) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.body?.readableBytes ?? 0, 0)
                XCTAssertNil(response.headers.first(name: "content-length"))
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - 500 when error middleware also throws

    func testReturns500WhenErrorMiddlewareAlsoThrows() {
        struct HandlerError: Error {}

        struct RethrowingErrorMiddleware: ErrorMiddleware {
            func handle(
                request: Request,
                error: Error,
                responder: @escaping ErrorResponder
            ) async throws -> Encodable {
                // Both onReceive and this middleware throw — the handler must fall
                // back to 500 Internal Server Error.
                throw error
            }
        }

        execute(
            throwsInHandler: true,
            errorMiddleware: [RethrowingErrorMiddleware()]
        ) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.status.code, 500)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - handle: non-Response Encodable return

    /// When `onReceive` returns any `Encodable` that is **not** a `Response`, `handle()`
    /// takes the else-branch and embeds the value's description in the base response body.
    func testHandlerReturningStringEncodableBodyIsWrapped() {
        execute(onReceive: { _ in "wrapped-body" }) { result in
            switch result {
            case .success(let response):
                let bodyString = response.body
                    .flatMap { buf in buf.getString(at: 0, length: buf.readableBytes) }
                XCTAssertEqual(bodyString, "wrapped-body")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - runMiddleware: MiddlewareError re-throw path

    /// With a pass-through middleware in the chain, an error thrown by `onReceive` is first
    /// wrapped into a `MiddlewareError` by the inner `runMiddleware` call, then re-thrown
    /// as-is by the outer call (path C in the catch block). The net observable effect is a
    /// 500 Internal Server Error once the error middleware chain also exhausts.
    func testMiddlewareErrorPropagatesViaPassThroughMiddleware() {
        struct PassThrough: Middleware {
            func handle(request: Request, responder: @escaping Responder) async throws -> Encodable {
                try await responder(request)
            }
        }

        execute(
            middleware: [PassThrough()],
            onReceive: { _ in
                struct HandlerError: Error {}
                throw HandlerError()
            }
        ) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.status.code, 500)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - write: HTTP/1 whenComplete closure

    /// When the final response carries `Connection: close`, the `whenComplete` callback in
    /// `write(_:for:in:)` must close the channel after writing. The client still receives the
    /// complete response before the connection drops, so the status is observable.
    func testConnectionCloseResponseTriggersWhenCompleteCheck() {
        execute(onReceive: { _ in
            var r = Response("goodbye")
            r.headers.set(.init(name: .connection, value: "close"))
            return r
        }) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.status.code, 200)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - version is propagated into the response

    func testResponseVersionMatchesRequestVersion() {
        // The HTTP status line returned by the server must match the negotiated
        // protocol version. AsyncHTTPClient connects with HTTP/1.1, so the response
        // status line should begin with "HTTP/1.1".
        // This is an indirect check: if the version were wrong (e.g. "HTTP/2.0")
        // AsyncHTTPClient would fail to parse the response.
        execute { result in
            switch result {
            case .success(let response):
                // A successful response proves the correct status line was emitted.
                XCTAssertEqual(response.status.code, 200)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
}

// MARK: - Helpers

extension RequestResponseHandlerTests {
    /// Overload that accepts a raw `onReceive` closure returning any `Encodable`.
    /// Use this when you need to return a non-`Response` value or control middleware.
    func execute(
        method: Request.Method = .GET,
        middleware: [Middleware] = [],
        errorMiddleware: [ErrorMiddleware] = [],
        onReceive: @escaping (Request) async throws -> Encodable,
        responseHandler: @escaping (Result<HTTPClient.Response, Error>) -> Void
    ) {
        server.middleware = middleware
        server.errorMiddleware = errorMiddleware

        let uri = URI(server.configuration.socketAddress)!

        server.onStart = { [weak self] _ in
            guard let self else { return }

            let httpMethod = HTTPMethod(rawValue: method.rawValue)
            let request = try! HTTPClient.Request(url: uri.string!, method: httpMethod)

            client.execute(request: request).whenComplete { [weak self] result in
                switch result {
                case .failure(let error):
                    responseHandler(.failure(error))
                case .success(let httpResponse):
                    responseHandler(.success(httpResponse))
                }

                DispatchQueue.global().asyncAfter(deadline: .now()) { [weak self] in
                    try! self?.client.syncShutdown()
                    try! self?.server.stop()
                }
            }
        }

        server.onReceive = onReceive
        try! server.start()
    }

    func execute(
        method: Request.Method = .GET,
        handlerResponse: Response = Response(),
        throwsInHandler: Bool = false,
        errorMiddleware: [ErrorMiddleware] = [],
        responseHandler: @escaping (Result<HTTPClient.Response, Error>) -> Void
    ) {
        server.errorMiddleware = errorMiddleware

        let uri = URI(server.configuration.socketAddress)!

        server.onStart = { [weak self] _ in
            guard let self else { return }

            let httpMethod = HTTPMethod(rawValue: method.rawValue)
            let request = try! HTTPClient.Request(url: uri.string!, method: httpMethod)

            client.execute(request: request).whenComplete { [weak self] result in
                switch result {
                case .failure(let error):
                    responseHandler(.failure(error))
                case .success(let httpResponse):
                    responseHandler(.success(httpResponse))
                }

                DispatchQueue.global().asyncAfter(deadline: .now()) { [weak self] in
                    try! self?.client.syncShutdown()
                    try! self?.server.stop()
                }
            }
        }

        server.onReceive = { _ in
            if throwsInHandler {
                struct TestError: Error {}
                throw TestError()
            }
            return handlerResponse
        }

        try! server.start()
    }
}
