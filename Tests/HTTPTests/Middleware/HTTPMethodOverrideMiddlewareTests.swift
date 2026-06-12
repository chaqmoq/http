@testable import HTTP
import XCTest

private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

final class HTTPMethodOverrideMiddlewareTests: XCTestCase, @unchecked Sendable {
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

        let receivedMethod = Box<Request.Method?>(nil)

        // Act
        _ = try await middleware.handle(request: request) { req in
            receivedMethod.value = req.method
            return Response()
        }

        // Assert
        XCTAssertEqual(receivedMethod.value, .DELETE)
    }

    func testOverrideViaPUTFormParameter() async throws {
        // Arrange
        let request = Request(
            eventLoop: eventLoop,
            method: .POST,
            headers: .init([.contentType: "application/x-www-form-urlencoded"]),
            body: .init(string: "_method=PUT")
        )

        let receivedMethod = Box<Request.Method?>(nil)
        _ = try await middleware.handle(request: request) { req in
            receivedMethod.value = req.method
            return Response()
        }

        XCTAssertEqual(receivedMethod.value, .PUT)
    }

    // MARK: - X-HTTP-Method-Override header

    func testOverrideViaHeader() async throws {
        // Arrange
        var request = Request(eventLoop: eventLoop, method: .POST)
        request.headers.set(.init(name: .xHTTPMethodOverride, value: "PATCH"))

        let receivedMethod = Box<Request.Method?>(nil)
        _ = try await middleware.handle(request: request) { req in
            receivedMethod.value = req.method
            return Response()
        }

        XCTAssertEqual(receivedMethod.value, .PATCH)
    }

    func testOverrideToTRACEIsRefusedByDefault() async throws {
        // TRACE is not in the default allowed-target set — the override must be ignored.
        var request = Request(eventLoop: eventLoop, method: .POST)
        request.headers.set(.init(name: .xHTTPMethodOverride, value: "TRACE"))

        let receivedMethod = Box<Request.Method?>(nil)
        _ = try await middleware.handle(request: request) { req in
            receivedMethod.value = req.method
            return Response()
        }

        XCTAssertEqual(receivedMethod.value, .POST)
    }

    func testOverrideToTRACEAllowedWhenConfigured() async throws {
        // Targets outside the default set can be opted into explicitly.
        let permissive = HTTPMethodOverrideMiddleware(
            options: .init(allowedTargetMethods: [.DELETE, .PATCH, .PUT, .TRACE])
        )
        var request = Request(eventLoop: eventLoop, method: .POST)
        request.headers.set(.init(name: .xHTTPMethodOverride, value: "TRACE"))

        let receivedMethod = Box<Request.Method?>(nil)
        _ = try await permissive.handle(request: request) { req in
            receivedMethod.value = req.method
            return Response()
        }

        XCTAssertEqual(receivedMethod.value, .TRACE)
    }

    // MARK: - Source method restrictions

    func testGETRequestIsNeverOverriddenByDefault() async throws {
        // Only POST is an eligible source method by default. A GET carrying the
        // override header must pass through unchanged — otherwise a plain link or
        // prefetcher could trigger a destructive method.
        var request = Request(eventLoop: eventLoop, method: .GET)
        request.headers.set(.init(name: .xHTTPMethodOverride, value: "DELETE"))

        let receivedMethod = Box<Request.Method?>(nil)
        _ = try await middleware.handle(request: request) { req in
            receivedMethod.value = req.method
            return Response()
        }

        XCTAssertEqual(receivedMethod.value, .GET)
    }

    func testOverrideToGETIsRefusedByDefault() async throws {
        // Tunneling to a safe method (GET) is refused to avoid cache interference.
        var request = Request(eventLoop: eventLoop, method: .POST)
        request.headers.set(.init(name: .xHTTPMethodOverride, value: "GET"))

        let receivedMethod = Box<Request.Method?>(nil)
        _ = try await middleware.handle(request: request) { req in
            receivedMethod.value = req.method
            return Response()
        }

        XCTAssertEqual(receivedMethod.value, .POST)
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

        let receivedMethod = Box<Request.Method?>(nil)
        _ = try await middleware.handle(request: request) { req in
            receivedMethod.value = req.method
            return Response()
        }

        // Form param (_method=DELETE) should win
        XCTAssertEqual(receivedMethod.value, .DELETE)
    }

    // MARK: - No override present

    func testNoOverridePassesOriginalMethod() async throws {
        // Arrange – plain GET request, no override
        let request = Request(eventLoop: eventLoop, method: .GET)

        let receivedMethod = Box<Request.Method?>(nil)
        _ = try await middleware.handle(request: request) { req in
            receivedMethod.value = req.method
            return Response()
        }

        XCTAssertEqual(receivedMethod.value, .GET)
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

        let receivedMethod = Box<Request.Method?>(nil)
        _ = try await middleware.handle(request: request) { req in
            receivedMethod.value = req.method
            return Response()
        }

        // Original method should be preserved when the override value is unknown
        XCTAssertEqual(receivedMethod.value, .POST)
    }

    func testInvalidHeaderValueIsIgnored() async throws {
        // Arrange
        var request = Request(eventLoop: eventLoop, method: .POST)
        request.headers.set(.init(name: .xHTTPMethodOverride, value: "NOT_A_METHOD"))

        let receivedMethod = Box<Request.Method?>(nil)
        _ = try await middleware.handle(request: request) { req in
            receivedMethod.value = req.method
            return Response()
        }

        XCTAssertEqual(receivedMethod.value, .POST)
    }
}
