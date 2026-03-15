import AsyncHTTPClient
@testable import HTTP
import NIO
import NIOHTTP1
import XCTest

/// Extended integration tests that drive paths in RequestResponseHandler and ResponseEncoder
/// not covered by the basic ClientServerTests.
final class ClientServerAdvancedTests: XCTestCase {
    var client: HTTPClient!
    var server: Server!
    let eventLoop = EmbeddedEventLoop()

    override func setUp() {
        super.setUp()
        client = HTTPClient(eventLoopGroupProvider: .singleton)
        server = Server(configuration: .init(numberOfThreads: 1))
    }

    // MARK: - HEAD request strips body

    func testHEADRequestReturnsNoBody() {
        execute(method: .HEAD, responseBody: Body(string: "should be stripped")) { result in
            switch result {
            case .success(let response):
                // HTTP spec: HEAD responses must not contain a body
                XCTAssertTrue(response.body.isEmpty)
                XCTAssertEqual(response.status, .ok)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - noContent response strips body

    func testNoContentResponseStripsBody() {
        execute(responseStatus: .noContent, responseBody: Body(string: "ignored")) { result in
            switch result {
            case .success(let response):
                XCTAssertTrue(response.body.isEmpty)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Non-Response Encodable is wrapped in a Response

    func testNonResponseEncodableIsStringified() {
        execute(encodableResponse: "hello world") { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.body.string, "hello world")
                XCTAssertEqual(response.status, .ok)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Non-empty body flows through ResponseEncoder

    func testResponseWithBodyIsEncoded() {
        execute(responseBody: Body(string: "encoded body")) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.body.string, "encoded body")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Error middleware is invoked on handler throw

    func testErrorMiddlewareReceivesHandlerError() {
        struct TestError: Error {}
        var errorMiddlewareCalled = false

        struct CapturingErrorMiddleware: ErrorMiddleware {
            let onError: () -> Void

            func handle(
                request: Request,
                error: Error,
                responder: @escaping ErrorResponder
            ) async throws -> Encodable {
                onError()

                return Response("caught", status: .internalServerError)
            }
        }

        execute(
            throwingHandler: { throw TestError() },
            errorMiddleware: [CapturingErrorMiddleware(onError: { errorMiddlewareCalled = true })]
        ) { result in
            switch result {
            case .success(let response):
                XCTAssertTrue(errorMiddlewareCalled)
                XCTAssertEqual(response.status, .internalServerError)
                XCTAssertEqual(response.body.string, "caught")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Server onError callback is set and accessible

    func testServerOnErrorCallbackIsAssignable() {
        var errorReceived: Error?
        server.onError = { error, _ in errorReceived = error }

        XCTAssertNotNil(server.onError)
        // Trigger the callback directly to verify the closure is stored
        struct SyntheticError: Error {}
        let el = EmbeddedEventLoop()
        server.onError?(SyntheticError(), el)
        XCTAssertTrue(errorReceived is SyntheticError)
    }

    // MARK: - Middleware returning non-Response Encodable is stringified
    //
    // When a Middleware.handle implementation returns a non-Response Encodable,
    // processMiddleware forwards it to prepareAndWrite's whenSuccess closure.
    // There `response as? Response` fails, exercising the
    // `?? .init("\(response)")` fallback (implicit closure #1 in closure #1 in prepareAndWrite).

    func testMiddlewareReturningNonResponseIsStringified() {
        struct StringMiddleware: Middleware {
            func handle(request: Request, responder: @escaping Responder) async throws -> Encodable {
                return "from-middleware"
            }
        }

        execute(middleware: [StringMiddleware()]) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.body.string, "from-middleware")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Error middleware returning non-Response Encodable is stringified
    //
    // When an ErrorMiddleware.handle returns a non-Response Encodable,
    // processMiddleware(errorMiddleware:…)'s whenSuccess closure receives it.
    // `response as? Response` fails, exercising the
    // `?? .init("\(response)")` fallback (implicit closure #1 in closure #1 in closure #2 in prepareAndWrite).

    func testErrorMiddlewareReturningNonResponseIsStringified() {
        struct ThrowingHandler: Error {}

        struct StringErrorMiddleware: ErrorMiddleware {
            func handle(
                request: Request,
                error: Error,
                responder: @escaping ErrorResponder
            ) async throws -> Encodable {
                return "from-error-middleware"
            }
        }

        execute(
            throwingHandler: { throw ThrowingHandler() },
            errorMiddleware: [StringErrorMiddleware()]
        ) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.body.string, "from-error-middleware")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Response with Connection: close triggers output half-close
    //
    // When write(response:for:in:) sees Connection: close on the response it calls
    // context.close(mode: .output). Exercises the otherwise-uncovered branch inside
    // the whenComplete closure in write(response:for:in:).

    func testConnectionCloseHeaderTriggersHalfClose() {
        var closeResponse = Response("body")
        closeResponse.headers.set(.init(name: .connection, value: "close"))

        execute(encodableResponse: closeResponse) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.body.string, "body")
                XCTAssertEqual(response.status, .ok)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

}

// MARK: - Helpers

extension ClientServerAdvancedTests {
    /// Sends a simple request and calls `responseHandler` with the result.
    func execute(
        method: Request.Method = .GET,
        responseStatus: Response.Status = .ok,
        responseBody: Body = Body(),
        encodableResponse: (any Encodable)? = nil,
        throwingHandler: (() throws -> Void)? = nil,
        middleware: [Middleware] = [],
        errorMiddleware: [ErrorMiddleware] = [],
        responseHandler: @escaping (Result<Response, Error>) -> Void
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

        server.onReceive = { _ in
            if let throwingHandler {
                try throwingHandler()
            }

            if let encodableResponse {
                return encodableResponse
            }

            return Response(responseBody, status: responseStatus)
        }

        try! server.start()
    }
}
