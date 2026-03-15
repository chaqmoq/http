@testable import HTTP
import XCTest

final class HTTPMethodOverrideMiddlewareTests: XCTestCase {
    let eventLoop = EmbeddedEventLoop()
    let middleware = HTTPMethodOverrideMiddleware()

    // MARK: - Form parameter override (_method)

    func testOverrideViaFormParameter() async throws {
        // Arrange – POST form with _method=DELETE
        let request = Request(
            eventLoop: eventLoop,
            method: .POST,
            headers: .init([.contentType: "application/x-www-form-urlencoded"]),
            body: .init(string: "_method=DELETE&id=42")
        )

        var receivedMethod: Request.Method?

        // Act
        _ = try await middleware.handle(request: request) { req in
            receivedMethod = req.method
            return Response()
        }

        // Assert
        XCTAssertEqual(receivedMethod, .DELETE)
    }

    func testOverrideViaPUTFormParameter() async throws {
        // Arrange
        let request = Request(
            eventLoop: eventLoop,
            method: .POST,
            headers: .init([.contentType: "application/x-www-form-urlencoded"]),
            body: .init(string: "_method=PUT")
        )

        var receivedMethod: Request.Method?
        _ = try await middleware.handle(request: request) { req in
            receivedMethod = req.method
            return Response()
        }

        XCTAssertEqual(receivedMethod, .PUT)
    }

    // MARK: - X-HTTP-Method-Override header

    func testOverrideViaHeader() async throws {
        // Arrange
        var request = Request(eventLoop: eventLoop, method: .POST)
        request.headers.set(.init(name: .xHTTPMethodOverride, value: "PATCH"))

        var receivedMethod: Request.Method?
        _ = try await middleware.handle(request: request) { req in
            receivedMethod = req.method
            return Response()
        }

        XCTAssertEqual(receivedMethod, .PATCH)
    }

    func testOverrideViaHeaderTRACE() async throws {
        // Arrange – TRACE is now a supported method
        var request = Request(eventLoop: eventLoop, method: .POST)
        request.headers.set(.init(name: .xHTTPMethodOverride, value: "TRACE"))

        var receivedMethod: Request.Method?
        _ = try await middleware.handle(request: request) { req in
            receivedMethod = req.method
            return Response()
        }

        XCTAssertEqual(receivedMethod, .TRACE)
    }

    // MARK: - Precedence: form parameter wins over header

    func testFormParameterTakesPrecedenceOverHeader() async throws {
        // Arrange
        let request = Request(
            eventLoop: eventLoop,
            method: .POST,
            headers: .init([
                .contentType: "application/x-www-form-urlencoded",
                .xHTTPMethodOverride: "PATCH"
            ]),
            body: .init(string: "_method=DELETE")
        )

        var receivedMethod: Request.Method?
        _ = try await middleware.handle(request: request) { req in
            receivedMethod = req.method
            return Response()
        }

        // Form param (_method=DELETE) should win
        XCTAssertEqual(receivedMethod, .DELETE)
    }

    // MARK: - No override present

    func testNoOverridePassesOriginalMethod() async throws {
        // Arrange – plain GET request, no override
        let request = Request(eventLoop: eventLoop, method: .GET)

        var receivedMethod: Request.Method?
        _ = try await middleware.handle(request: request) { req in
            receivedMethod = req.method
            return Response()
        }

        XCTAssertEqual(receivedMethod, .GET)
    }

    // MARK: - Invalid / unknown method values are ignored

    func testInvalidFormParameterValueIsIgnored() async throws {
        // Arrange
        let request = Request(
            eventLoop: eventLoop,
            method: .POST,
            headers: .init([.contentType: "application/x-www-form-urlencoded"]),
            body: .init(string: "_method=INVALID_METHOD")
        )

        var receivedMethod: Request.Method?
        _ = try await middleware.handle(request: request) { req in
            receivedMethod = req.method
            return Response()
        }

        // Original method should be preserved when the override value is unknown
        XCTAssertEqual(receivedMethod, .POST)
    }

    func testInvalidHeaderValueIsIgnored() async throws {
        // Arrange
        var request = Request(eventLoop: eventLoop, method: .POST)
        request.headers.set(.init(name: .xHTTPMethodOverride, value: "NOT_A_METHOD"))

        var receivedMethod: Request.Method?
        _ = try await middleware.handle(request: request) { req in
            receivedMethod = req.method
            return Response()
        }

        XCTAssertEqual(receivedMethod, .POST)
    }
}
