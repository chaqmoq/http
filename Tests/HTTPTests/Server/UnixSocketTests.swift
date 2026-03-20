@testable import HTTP
import Foundation
import NIO
import NIOHTTP1
import XCTest
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

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

    // MARK: - Server binds and accepts requests over a Unix socket

    /// Uses HTTP/1.0 so the server automatically adds `Connection: close` and
    /// closes the connection after the response — the same pattern used in
    /// `RequestResponseHandlerTests.testHTTP10WithoutConnectionHeaderSetsConnectionClose`.
    /// HTTP/1.1 keep-alive would leave the connection open indefinitely and hang the test.
    func testHTTP10RequestOverUnixSocket() {
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

                // HTTP/1.0: connection is closed by default after response.
                var buf = channel.allocator.buffer(capacity: 48)
                buf.writeString("GET / HTTP/1.0\r\nHost: localhost\r\n\r\n")
                try? channel.writeAndFlush(buf).wait()

                // Server closes its output half after responding; channelInactive fires here.
                capture.waitForClose(timeout: 5)
                responseStatus = capture.firstLine
                semaphore.signal()
                try! self.server.stop()
            }
        }

        try! server.start()
        semaphore.wait()

        XCTAssertNotNil(responseStatus)
        XCTAssertTrue(
            responseStatus?.hasPrefix("HTTP/1.0 200") == true,
            "Expected HTTP/1.0 200, got \(responseStatus ?? "nil")"
        )
    }

    // MARK: - Server start cleans up a stale socket file

    func testServerCleansUpStaleSocketFile() {
        // NIO's cleanupExistingSocketFile: true calls stat() and checks S_IFSOCK before
        // removing the file — a plain file created by FileManager would throw
        // UnixDomainSocketPathWrongType. We must create a real Unix domain socket.
        makeStaleSocketFile(at: socketPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: socketPath))

        // Strong capture — avoids a weak-ref race where self becomes nil before the
        // background task runs, which would leave stop() uncalled and start() hanging.
        let capturedServer = server!
        server.onReceive = { _ in Response() }
        server.onStart = { _ in
            // Dispatch off the event loop so stop() can drain it.
            DispatchQueue.global().async {
                try? capturedServer.stop()
            }
        }

        // start() blocks until the server stops, so no semaphore is needed.
        XCTAssertNoThrow(try server.start())
    }
}

// MARK: - Helpers

/// Binds a POSIX Unix-domain socket to `path` and then closes the file descriptor
/// *without* calling `unlink`, leaving a real socket file (`S_IFSOCK`) on disk.
///
/// NIO's `cleanupExistingSocketFile: true` uses `stat(2)` to confirm the path refers
/// to a socket before removing it. A plain file (e.g. from `FileManager.createFile`)
/// would cause NIO to throw `UnixDomainSocketPathWrongType`, so the test must plant a
/// real socket here.
private func makeStaleSocketFile(at path: String) {
    #if canImport(Darwin)
    let sockStreamType: Int32 = SOCK_STREAM
    #else
    let sockStreamType = Int32(SOCK_STREAM.rawValue)
    #endif

    let fd = socket(AF_UNIX, sockStreamType, 0)
    guard fd >= 0 else { return }
    defer { close(fd) }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let capacity = MemoryLayout.size(ofValue: addr.sun_path)
    path.withCString { src in
        withUnsafeMutablePointer(to: &addr.sun_path) { dest in
            UnsafeMutableRawPointer(dest)
                .copyMemory(from: src, byteCount: min(Int(strlen(src)) + 1, capacity - 1))
        }
    }
    withUnsafePointer(to: addr) { ptr in
        _ = ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }
    // close(fd) via defer — does NOT unlink the socket file.
    // The file remains on disk as the stale artifact the test wants to exercise.
}

// MARK: - RawHTTPCapture

/// Accumulates raw bytes from the server response and signals when the channel closes.
private final class RawHTTPCapture: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer

    private var accumulated = ""
    private let semaphore = DispatchSemaphore(value: 0)
    private let lock = NSLock()

    var firstLine: String? {
        lock.lock()
        defer { lock.unlock() }
        return accumulated.components(separatedBy: "\r\n").first
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buf = unwrapInboundIn(data)
        if let str = buf.readString(length: buf.readableBytes) {
            lock.lock()
            accumulated += str
            lock.unlock()
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        semaphore.signal()
    }

    func waitForClose(timeout: TimeInterval = .infinity) {
        if timeout == .infinity {
            semaphore.wait()
        } else {
            _ = semaphore.wait(timeout: .now() + timeout)
        }
    }
}
