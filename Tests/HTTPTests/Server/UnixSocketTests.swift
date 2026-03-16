@testable import HTTP
import Foundation
import NIO
import NIOHTTP1
import XCTest

/// Integration tests for Unix domain socket support in `Server`.
///
/// Each test binds the server to a temporary socket path in `/tmp`, connects via
/// `ClientBootstrap.connect(unixDomainSocketPath:)`, and exchanges a minimal
/// HTTP/1.1 request/response pair.
final class UnixSocketTests: XCTestCase {
    var server: Server!
    private var socketPath: String!

    override func setUp() {
        super.setUp()
        // Use a unique path per test to avoid cross-test interference.
        socketPath = "/tmp/http-test-\(UUID().uuidString).sock"
        server = Server(
            configuration: .init(
                unixSocketPath: socketPath,
                numberOfThreads: 1
            )
        )
    }

    override func tearDown() {
        // Remove any stale socket file (server.start already cleans up on bind,
        // but tearDown handles the case where start() was never called).
        try? FileManager.default.removeItem(atPath: socketPath)
        super.tearDown()
    }

    // MARK: - Configuration

    func testUnixSocketPathDefaultIsNil() {
        let config = Server.Configuration()
        XCTAssertNil(config.unixSocketPath)
    }

    func testUnixSocketPathCanBeSet() {
        let path = "/tmp/test.sock"
        let config = Server.Configuration(unixSocketPath: path)
        XCTAssertEqual(config.unixSocketPath, path)
    }

    func testUnixSocketPathCanBeMutated() {
        var config = Server.Configuration()
        XCTAssertNil(config.unixSocketPath)
        config.unixSocketPath = "/tmp/mutated.sock"
        XCTAssertEqual(config.unixSocketPath, "/tmp/mutated.sock")
    }

    // MARK: - Server binds and accepts HTTP/1.1 requests over a Unix socket

    func testHTTP11RequestOverUnixSocket() {
        var responseStatus: String?
        let semaphore = DispatchSemaphore(value: 0)

        server.onReceive = { _ in Response("unix-ok") }

        server.onStart = { [weak self] _ in
            guard let self else { return }
            DispatchQueue.global().async {
                let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
                defer { try? group.syncShutdownGracefully() }

                let capture = RawHTTPCapture()
                let channel = try? ClientBootstrap(group: group)
                    .channelInitializer { $0.pipeline.addHandler(capture) }
                    .connect(unixDomainSocketPath: self.socketPath)
                    .wait()

                guard let channel else {
                    semaphore.signal()
                    try! self.server.stop()
                    return
                }

                var buf = channel.allocator.buffer(capacity: 64)
                buf.writeString("GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
                try? channel.writeAndFlush(buf).wait()

                capture.waitForClose()
                responseStatus = capture.firstLine
                semaphore.signal()
                try! self.server.stop()
            }
        }

        try! server.start()
        semaphore.wait()

        XCTAssertNotNil(responseStatus)
        XCTAssertTrue(
            responseStatus?.hasPrefix("HTTP/1.1 200") == true,
            "Expected HTTP/1.1 200, got \(responseStatus ?? "nil")"
        )
    }

    // MARK: - Server start cleans up a stale socket file

    func testServerCleansUpStaleSocketFile() {
        // Pre-create a file at the socket path to simulate a stale socket from a prior run.
        FileManager.default.createFile(atPath: socketPath, contents: nil)
        XCTAssertTrue(FileManager.default.fileExists(atPath: socketPath))

        let semaphore = DispatchSemaphore(value: 0)
        server.onReceive = { _ in Response() }
        server.onStart = { [weak self] _ in
            DispatchQueue.global().async {
                semaphore.signal()
                try! self?.server.stop()
            }
        }

        // If start() throws (bind fails because file exists without cleanup), the test fails.
        XCTAssertNoThrow(try server.start())
        semaphore.wait()
    }
}

// MARK: - RawHTTPCapture

/// Accumulates raw bytes from the server response and signals when the channel closes.
private final class RawHTTPCapture: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer

    private var accumulated = ""
    private let semaphore = DispatchSemaphore(value: 0)
    private let lock = NIOLock()

    var firstLine: String? {
        lock.withLock {
            accumulated.components(separatedBy: "\r\n").first
        }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buf = unwrapInboundIn(data)
        if let str = buf.readString(length: buf.readableBytes) {
            lock.withLock { accumulated += str }
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        semaphore.signal()
    }

    func waitForClose() {
        semaphore.wait()
    }
}
