import XCTest
@testable import HTTP

final class ServerTests: XCTestCase {
    func testInit() {
        // Arrange
        let server = Server()

        // Assert
        XCTAssertNotNil(server.configuration)
        XCTAssertNotNil(server.logger)
        XCTAssertEqual(server.logger.label, server.configuration.identifier)
        XCTAssertNil(server.onStart)
        XCTAssertNil(server.onStop)
        XCTAssertNil(server.onError)
        XCTAssertNil(server.onReceive)
    }

    func testUpdate() {
        // Arrange
        let server = Server()

        // Act
        server.onStart = { _ in }
        server.onStop = {}
        server.onError = { _, _ in }
        server.onReceive = { _, _ in Response() }

        // Assert
        XCTAssertNotNil(server.configuration)
        XCTAssertNotNil(server.logger)
        XCTAssertEqual(server.logger.label, server.configuration.identifier)
        XCTAssertNotNil(server.onStart)
        XCTAssertNotNil(server.onStop)
        XCTAssertNotNil(server.onError)
        XCTAssertNotNil(server.onReceive)
    }
}
