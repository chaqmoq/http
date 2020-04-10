import NIO
import XCTest
@testable import HTTP

final class ServerTests: XCTestCase {
    static var allTests = [
        ("testDefaultConfiguration", testDefaultConfiguration)
    ]

    func testDefaultConfiguration() {
        // Arrange
        let configuration = Server.Configuration()

        // Assert
        XCTAssertEqual(configuration.identifier, "dev.chaqmoq.http")
        XCTAssertEqual(configuration.host, "127.0.0.1")
        XCTAssertEqual(configuration.port, 8080)
        XCTAssertEqual(configuration.scheme, "http")
        XCTAssertEqual(configuration.socketAddress, "http://127.0.0.1:8080")
        XCTAssertNil(configuration.serverName)
        XCTAssertNil(configuration.tls)
        XCTAssertEqual(configuration.supportsVersions, [.one, .two])
        XCTAssertFalse(configuration.supportsPipelining)
        XCTAssertEqual(configuration.numberOfThreads, System.coreCount)
        XCTAssertEqual(configuration.backlog, 256)
        XCTAssertTrue(configuration.reuseAddress)
        XCTAssertTrue(configuration.tcpNoDelay)
        XCTAssertEqual(configuration.maxMessagesPerRead, 16)
    }
}
