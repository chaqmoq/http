@testable import HTTP
import XCTest

final class MiddlewareTests: XCTestCase {
    func testHandleRequestResponse() {
        // Arrange
        final class TestMiddleware: Middleware {}
        let middleware = TestMiddleware()
        var request = Request()
        var response = Response()

        // Act/Assert
        XCTAssertTrue((middleware.handleRequest(&request) {} is Void))
        XCTAssertTrue((middleware.handleResponse(&response) {} is Void))
    }
}
