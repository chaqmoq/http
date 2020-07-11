@testable import HTTP
import XCTest

final class ServerTests: XCTestCase {
    var server: Server!

    override func setUp() {
        super.setUp()

        // Arrange
        server = Server(configuration: .init(numberOfThreads: 1))
    }

    func testInit() {
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
