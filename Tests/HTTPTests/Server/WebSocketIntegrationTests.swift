@testable import HTTP
import Foundation
import NIO
import NIOHTTP1
import NIOWebSocket
import XCTest

/// Integration tests for WebSocket upgrade support in `Server`.
///
/// Each test starts a real TCP server on port 8090, performs a WebSocket upgrade
/// using NIO's `NIOWebSocketClientUpgrader`, exchanges frames, and shuts down.
///
/// The server is stopped from within `onStart` after the client interaction
/// completes, following the same pattern as the rest of the integration test suite.
final class WebSocketIntegrationTests: XCTestCase {
    private static let port = 8090
    var server: Server!

    override func setUp() {
        super.setUp()
        server = Server(configuration: .init(port: Self.port, numberOfThreads: 1))
    }

    // MARK: - onUpgrade is nil by default

    func testOnUpgradeIsNilByDefault() {
        XCTAssertNil(server.onUpgrade)
    }

    // MARK: - onUpgrade can be set and cleared

    func testOnUpgradeCanBeSetAndCleared() {
        server.onUpgrade = { _, _ in }
        XCTAssertNotNil(server.onUpgrade)
        server.onUpgrade = nil
        XCTAssertNil(server.onUpgrade)
    }

    // MARK: - Echo server: text messages are echoed back

    func testWebSocketTextEcho() {
        var receivedText: String?
        let semaphore = DispatchSemaphore(value: 0)

        server.onUpgrade = { _, ws in
            for try await message in ws.messages {
                if case .text(let t) = message {
                    try await ws.send("echo: \(t)")
                }
            }
        }

        server.onStart = { [weak self] _ in
            guard let self else { return }
            DispatchQueue.global().async {
                let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
                defer { try? group.syncShutdownGracefully() }

                let capture = WebSocketMessageCapture()
                let upgrader = NIOWebSocketClientUpgrader(
                    requestKey: "dGhlIHNhbXBsZSBub25jZQ==",
                    upgradePipelineHandler: { channel, _ in
                        channel.pipeline.addHandler(capture)
                    }
                )
                let config: NIOHTTPClientUpgradeConfiguration = (
                    upgraders: [upgrader],
                    completionHandler: { _ in }
                )

                let channel = try? ClientBootstrap(group: group)
                    .channelInitializer { ch in
                        ch.pipeline.addHTTPClientHandlers(withClientUpgrade: config)
                    }
                    .connect(host: "127.0.0.1", port: Self.port)
                    .wait()

                guard let channel else {
                    semaphore.signal()
                    try! self.server.stop()
                    return
                }

                // Send a WebSocket upgrade request.
                var headers = HTTPHeaders()
                headers.add(name: "Host", value: "127.0.0.1:\(Self.port)")
                headers.add(name: "Content-Type", value: "text/plain")
                let requestHead = HTTPRequestHead(
                    version: .http1_1,
                    method: .GET,
                    uri: "/",
                    headers: headers
                )
                try? channel.writeAndFlush(HTTPClientRequestPart.head(requestHead)).wait()
                try? channel.writeAndFlush(HTTPClientRequestPart.end(nil)).wait()

                // Wait for handlerAdded to fire (upgrade complete) and reply.
                Thread.sleep(forTimeInterval: 0.3)

                // Send a text frame (server frames are unmasked; client frames must be masked).
                var buf = channel.allocator.buffer(capacity: 5)
                buf.writeString("hello")
                let frame = WebSocketFrame(fin: true, opcode: .text, maskKey: .random(), data: buf)
                try? channel.writeAndFlush(frame).wait()

                // Give the server a moment to process and echo.
                Thread.sleep(forTimeInterval: 0.3)
                receivedText = capture.lastText
                semaphore.signal()

                // Send a close frame so the server loop exits cleanly.
                var closeBuf = channel.allocator.buffer(capacity: 2)
                closeBuf.write(webSocketErrorCode: .normalClosure)
                let closeFrame = WebSocketFrame(fin: true, opcode: .connectionClose, maskKey: .random(), data: closeBuf)
                try? channel.writeAndFlush(closeFrame).wait()
                Thread.sleep(forTimeInterval: 0.1)
                try! self.server.stop()
            }
        }

        try! server.start()
        semaphore.wait()
        XCTAssertEqual(receivedText, "echo: hello")
    }

    // MARK: - Binary echo

    func testWebSocketBinaryEcho() {
        var receivedBytes: [UInt8]?
        let semaphore = DispatchSemaphore(value: 0)

        server.onUpgrade = { _, ws in
            for try await message in ws.messages {
                if case .binary(let data) = message {
                    try await ws.send(data)
                }
            }
        }

        server.onStart = { [weak self] _ in
            guard let self else { return }
            DispatchQueue.global().async {
                let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
                defer { try? group.syncShutdownGracefully() }

                let capture = WebSocketMessageCapture()
                let upgrader = NIOWebSocketClientUpgrader(
                    requestKey: "dGhlIHNhbXBsZSBub25jZQ==",
                    upgradePipelineHandler: { channel, _ in
                        channel.pipeline.addHandler(capture)
                    }
                )
                let config: NIOHTTPClientUpgradeConfiguration = (
                    upgraders: [upgrader],
                    completionHandler: { _ in }
                )

                let channel = try? ClientBootstrap(group: group)
                    .channelInitializer { ch in
                        ch.pipeline.addHTTPClientHandlers(withClientUpgrade: config)
                    }
                    .connect(host: "127.0.0.1", port: Self.port)
                    .wait()

                guard let channel else {
                    semaphore.signal()
                    try! self.server.stop()
                    return
                }

                var headers = HTTPHeaders()
                headers.add(name: "Host", value: "127.0.0.1:\(Self.port)")
                let requestHead = HTTPRequestHead(
                    version: .http1_1, method: .GET, uri: "/", headers: headers
                )
                try? channel.writeAndFlush(HTTPClientRequestPart.head(requestHead)).wait()
                try? channel.writeAndFlush(HTTPClientRequestPart.end(nil)).wait()
                Thread.sleep(forTimeInterval: 0.3)

                var buf = channel.allocator.buffer(capacity: 3)
                buf.writeBytes([0x01, 0x02, 0x03])
                let frame = WebSocketFrame(fin: true, opcode: .binary, maskKey: .random(), data: buf)
                try? channel.writeAndFlush(frame).wait()
                Thread.sleep(forTimeInterval: 0.3)

                if let bytes = capture.lastBinaryBytes {
                    receivedBytes = bytes
                }
                semaphore.signal()

                var closeBuf = channel.allocator.buffer(capacity: 2)
                closeBuf.write(webSocketErrorCode: .normalClosure)
                let closeFrame = WebSocketFrame(
                    fin: true, opcode: .connectionClose, maskKey: .random(), data: closeBuf
                )
                try? channel.writeAndFlush(closeFrame).wait()
                Thread.sleep(forTimeInterval: 0.1)
                try! self.server.stop()
            }
        }

        try! server.start()
        semaphore.wait()
        XCTAssertEqual(receivedBytes, [0x01, 0x02, 0x03])
    }

    // MARK: - close() sends close frame

    func testWebSocketCloseFromServer() {
        let closeSemaphore = DispatchSemaphore(value: 0)
        var serverClosed = false

        server.onUpgrade = { _, ws in
            // Close immediately without waiting for messages.
            try await ws.close()
            serverClosed = true
        }

        server.onStart = { [weak self] _ in
            guard let self else { return }
            DispatchQueue.global().async {
                let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
                defer { try? group.syncShutdownGracefully() }

                let capture = WebSocketMessageCapture()
                let upgrader = NIOWebSocketClientUpgrader(
                    requestKey: "dGhlIHNhbXBsZSBub25jZQ==",
                    upgradePipelineHandler: { channel, _ in
                        channel.pipeline.addHandler(capture)
                    }
                )
                let config: NIOHTTPClientUpgradeConfiguration = (
                    upgraders: [upgrader],
                    completionHandler: { _ in }
                )

                let channel = try? ClientBootstrap(group: group)
                    .channelInitializer { ch in
                        ch.pipeline.addHTTPClientHandlers(withClientUpgrade: config)
                    }
                    .connect(host: "127.0.0.1", port: Self.port)
                    .wait()

                guard let channel else {
                    closeSemaphore.signal()
                    try! self.server.stop()
                    return
                }

                var headers = HTTPHeaders()
                headers.add(name: "Host", value: "127.0.0.1:\(Self.port)")
                let requestHead = HTTPRequestHead(
                    version: .http1_1, method: .GET, uri: "/", headers: headers
                )
                try? channel.writeAndFlush(HTTPClientRequestPart.head(requestHead)).wait()
                try? channel.writeAndFlush(HTTPClientRequestPart.end(nil)).wait()
                Thread.sleep(forTimeInterval: 0.5)

                closeSemaphore.signal()
                try! self.server.stop()
            }
        }

        try! server.start()
        closeSemaphore.wait()
        XCTAssertTrue(serverClosed, "Server's onUpgrade handler should have run to completion")
    }
}

// MARK: - WebSocketMessageCapture

/// A simple `ChannelInboundHandler` that captures the most recent inbound `WebSocketFrame`
/// from the client side so integration tests can inspect server-sent messages.
private final class WebSocketMessageCapture: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = WebSocketFrame

    private var _lastText: String?
    private var _lastBinaryBytes: [UInt8]?
    private let lock = NSLock()

    var lastText: String? {
        lock.lock()
        defer { lock.unlock() }
        return _lastText
    }

    var lastBinaryBytes: [UInt8]? {
        lock.lock()
        defer { lock.unlock() }
        return _lastBinaryBytes
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = unwrapInboundIn(data)
        switch frame.opcode {
        case .text:
            var buf = frame.unmaskedData
            let text = buf.readString(length: buf.readableBytes) ?? ""
            lock.lock()
            _lastText = text
            lock.unlock()
        case .binary:
            let buf = frame.unmaskedData
            let bytes = buf.getBytes(at: buf.readerIndex, length: buf.readableBytes) ?? []
            lock.lock()
            _lastBinaryBytes = bytes
            lock.unlock()
        default:
            break
        }
    }
}
