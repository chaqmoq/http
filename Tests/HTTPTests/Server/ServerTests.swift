import enum NIO.System
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

    func testCustomConfiguration() {
        // Arrange
        let identifier = "com.example.http"
        let host = "localhost"
        let port = 8888
        let serverName = "Example"
        let tls: TLS? = nil // TODO: add a sample certificate and private key
        let supportsVersions: Set<Version.Major> = [.one]
        let supportsPipelining = true
        let numberOfThreads = 1
        let backlog: Int32 = 255
        let reuseAddress = false
        let tcpNoDelay = false
        let maxMessagesPerRead: UInt = 1
        let configuration = Server.Configuration(
            identifier: identifier,
            host: host,
            port: port,
            serverName: serverName,
            tls: tls,
            supportsVersions: supportsVersions,
            supportsPipelining: supportsPipelining,
            numberOfThreads: numberOfThreads,
            backlog: backlog,
            reuseAddress: reuseAddress,
            tcpNoDelay: tcpNoDelay,
            maxMessagesPerRead: maxMessagesPerRead
        )

        // Assert
        XCTAssertEqual(configuration.identifier, identifier)
        XCTAssertEqual(configuration.host, host)
        XCTAssertEqual(configuration.port, port)
        XCTAssertEqual(configuration.scheme, "http")
        XCTAssertEqual(configuration.socketAddress, "http://localhost:8888")
        XCTAssertEqual(configuration.serverName, serverName)
        XCTAssertEqual(configuration.tls, tls)
        XCTAssertEqual(configuration.supportsVersions, supportsVersions)
        XCTAssertEqual(configuration.supportsPipelining, supportsPipelining)
        XCTAssertEqual(configuration.numberOfThreads, numberOfThreads)
        XCTAssertEqual(configuration.backlog, backlog)
        XCTAssertEqual(configuration.reuseAddress, reuseAddress)
        XCTAssertEqual(configuration.tcpNoDelay, tcpNoDelay)
        XCTAssertEqual(configuration.maxMessagesPerRead, maxMessagesPerRead)
    }

    func testUpdateConfiguration() {
        // Arrange
        let identifier = "com.example.http"
        let host = "localhost"
        let port = 8888
        let serverName = "Example"
        let tls: TLS? = nil // TODO: add a sample certificate and private key
        let supportsVersions: Set<Version.Major> = [.one]
        let supportsPipelining = true
        let numberOfThreads = 1
        let backlog: Int32 = 255
        let reuseAddress = false
        let tcpNoDelay = false
        let maxMessagesPerRead: UInt = 1
        var configuration = Server.Configuration()

        // Act
        configuration.identifier = identifier
        configuration.host = host
        configuration.port = port
        configuration.serverName = serverName
        configuration.tls = tls
        configuration.supportsVersions = supportsVersions
        configuration.supportsPipelining = supportsPipelining
        configuration.numberOfThreads = numberOfThreads
        configuration.backlog = backlog
        configuration.reuseAddress = reuseAddress
        configuration.tcpNoDelay = tcpNoDelay
        configuration.maxMessagesPerRead = maxMessagesPerRead

        // Assert
        XCTAssertEqual(configuration.identifier, identifier)
        XCTAssertEqual(configuration.host, host)
        XCTAssertEqual(configuration.port, port)
        XCTAssertEqual(configuration.scheme, "http")
        XCTAssertEqual(configuration.socketAddress, "http://localhost:8888")
        XCTAssertEqual(configuration.serverName, serverName)
        XCTAssertEqual(configuration.tls, tls)
        XCTAssertEqual(configuration.supportsVersions, supportsVersions)
        XCTAssertEqual(configuration.supportsPipelining, supportsPipelining)
        XCTAssertEqual(configuration.numberOfThreads, numberOfThreads)
        XCTAssertEqual(configuration.backlog, backlog)
        XCTAssertEqual(configuration.reuseAddress, reuseAddress)
        XCTAssertEqual(configuration.tcpNoDelay, tcpNoDelay)
        XCTAssertEqual(configuration.maxMessagesPerRead, maxMessagesPerRead)
    }
}
