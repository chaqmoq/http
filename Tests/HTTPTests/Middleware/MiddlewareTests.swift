@testable import HTTP
import XCTest

private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

// MARK: - Concrete types using default protocol implementations

/// A middleware that relies entirely on the default `handle` implementation (pass-through).
private struct PassThroughMiddleware: Middleware {}

/// An error middleware that relies entirely on the default `handle` implementation (re-throws).
private struct PassThroughErrorMiddleware: ErrorMiddleware {}

// MARK: - Tests

final class MiddlewareTests: XCTestCase, @unchecked Sendable {
    let eventLoop = EmbeddedEventLoop()

    // MARK: - Middleware default implementation

    func testDefaultMiddlewareForwardsRequestUnchanged() async throws {
        // Arrange
        let middleware = PassThroughMiddleware()
        let original = Request(eventLoop: eventLoop, method: .GET, uri: URI("/hello")!)
        let received = Box<Request?>(nil)

        // Act
        let result = try await middleware.handle(request: original) { request in
            received.value = request

            return Response("ok")
        }

        // Assert
        XCTAssertEqual(received.value?.uri, original.uri)
        XCTAssertEqual(received.value?.method, original.method)
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
        let receivedError = Box<Error?>(nil)

        // Act
        let result = try await middleware.handle(request: request, error: thrown) { _, error in
            receivedError.value = error

            return Response("handled")
        }

        // Assert
        XCTAssertTrue(receivedError.value is TestError)
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
