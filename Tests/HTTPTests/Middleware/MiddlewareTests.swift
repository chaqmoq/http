@testable import HTTP
import XCTest

// MARK: - Concrete types using default protocol implementations

/// A middleware that relies entirely on the default `handle` implementation (pass-through).
private struct PassThroughMiddleware: Middleware {}

/// An error middleware that relies entirely on the default `handle` implementation (re-throws).
private struct PassThroughErrorMiddleware: ErrorMiddleware {}

// MARK: - Tests

final class MiddlewareTests: XCTestCase {
    let eventLoop = EmbeddedEventLoop()

    // MARK: - Middleware default implementation

    func testDefaultMiddlewareForwardsRequestUnchanged() async throws {
        // Arrange
        let middleware = PassThroughMiddleware()
        let original = Request(eventLoop: eventLoop, method: .GET, uri: URI("/hello")!)
        var received: Request?

        // Act
        let result = try await middleware.handle(request: original) { request in
            received = request

            return Response("ok")
        }

        // Assert
        XCTAssertEqual(received?.uri, original.uri)
        XCTAssertEqual(received?.method, original.method)
        let response = result as? Response
        XCTAssertEqual(response?.body.string, "ok")
    }

    func testDefaultMiddlewareDoesNotMutateResponse() async throws {
        // Arrange
        let middleware = PassThroughMiddleware()
        let request = Request(eventLoop: eventLoop)
        let expected = Response("untouched", status: .created)

        // Act
        let result = try await middleware.handle(request: request) { _ in expected }
        let response = result as? Response

        // Assert
        XCTAssertEqual(response?.status, .created)
        XCTAssertEqual(response?.body.string, "untouched")
    }

    func testDefaultMiddlewarePropagatesThrows() async {
        // Arrange
        let middleware = PassThroughMiddleware()
        let request = Request(eventLoop: eventLoop)

        struct TestError: Error {}

        // Act & Assert
        do {
            _ = try await middleware.handle(request: request) { _ in throw TestError() }
            XCTFail("Expected throw")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    // MARK: - ErrorMiddleware default implementation

    func testDefaultErrorMiddlewareForwardsToNextResponder() async throws {
        // Arrange
        let middleware = PassThroughErrorMiddleware()
        let request = Request(eventLoop: eventLoop)

        struct TestError: Error, Equatable {}
        let thrown = TestError()
        var receivedError: Error?

        // Act
        let result = try await middleware.handle(request: request, error: thrown) { _, error in
            receivedError = error

            return Response("handled")
        }

        // Assert
        XCTAssertTrue(receivedError is TestError)
        let response = result as? Response
        XCTAssertEqual(response?.body.string, "handled")
    }

    func testDefaultErrorMiddlewarePropagatesThrowsFromNextResponder() async {
        // Arrange
        let middleware = PassThroughErrorMiddleware()
        let request = Request(eventLoop: eventLoop)

        struct OriginalError: Error {}
        struct NextError: Error {}

        // Act & Assert
        do {
            _ = try await middleware.handle(request: request, error: OriginalError()) { _, _ in
                throw NextError()
            }
            XCTFail("Expected throw")
        } catch {
            XCTAssertTrue(error is NextError)
        }
    }
}
