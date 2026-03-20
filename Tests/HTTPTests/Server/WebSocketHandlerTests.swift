@testable import HTTP
import NIO
import NIOWebSocket
import XCTest

/// Unit tests for `WebSocketHandler` using a synchronous `EmbeddedChannel`.
///
/// Frames are written directly into the channel's inbound pipeline; the handler's
/// outbound responses (pong, close echo) are read back from the channel's outbound
/// buffer.
///
/// All channel operations (`writeInbound`, `fireChannelInactive`, etc.) are kept
/// on the XCTest thread — the same thread that created the `EmbeddedChannel` in
/// `setUp()` — to avoid NIO's "EmbeddedEventLoop is not thread-safe" assertion.
/// Async `webSocket.messages` assertions are driven through `Task` +
/// `XCTestExpectation` so `await` never touches the channel.
final class WebSocketHandlerTests: XCTestCase {
    private var webSocket: WebSocket!
    private var channel: EmbeddedChannel!

    override func setUp() {
        super.setUp()
        channel = EmbeddedChannel()
        let request = Request(eventLoop: channel.embeddedEventLoop)
        webSocket = WebSocket(request: request, channel: channel)
        try! channel.pipeline.addHandler(WebSocketHandler(webSocket: webSocket)).wait()
    }

    override func tearDown() {
        _ = try? channel.finish()
        super.tearDown()
    }

    // MARK: - Text frame

    func testTextFrameYieldsTextMessage() {
        var buffer = channel.allocator.buffer(capacity: 3)
        buffer.writeString("hi!")
        // Client frames carry a mask key per RFC 6455 §5.3.
        let frame = WebSocketFrame(fin: true, opcode: .text, maskKey: nil, data: buffer)
        // Channel operation stays on the test thread.
        try! channel.writeInbound(frame)

        let exp = expectation(description: "text message")
        var receivedText: String?
        let ws = webSocket!
        Task {
            var iterator = ws.messages.makeAsyncIterator()
            let message = await iterator.next()
            if case .text(let text) = message {
                receivedText = text
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedText, "hi!")
    }

    // MARK: - Binary frame

    func testBinaryFrameYieldsBinaryMessage() {
        var buffer = channel.allocator.buffer(capacity: 3)
        buffer.writeBytes([0xDE, 0xAD, 0xBE])
        let frame = WebSocketFrame(fin: true, opcode: .binary, maskKey: nil, data: buffer)
        try! channel.writeInbound(frame)

        let exp = expectation(description: "binary message")
        var receivedBytes: Int?
        let ws = webSocket!
        Task {
            var iterator = ws.messages.makeAsyncIterator()
            let message = await iterator.next()
            if case .binary(let data) = message {
                receivedBytes = data.readableBytes
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(receivedBytes, 3)
    }

    // MARK: - Ping → Pong (RFC 6455 §5.5.2)

    func testPingFrameRepliesWithPong() throws {
        var buffer = channel.allocator.buffer(capacity: 4)
        buffer.writeString("ping")
        let frame = WebSocketFrame(fin: true, opcode: .ping, maskKey: nil, data: buffer)
        try channel.writeInbound(frame)

        let pong = try XCTUnwrap(channel.readOutbound(as: WebSocketFrame.self))
        XCTAssertEqual(pong.opcode, .pong)
        // Pong payload must mirror the ping payload (RFC 6455 §5.5.3).
        XCTAssertEqual(pong.unmaskedData.readableBytes, buffer.readableBytes)
    }

    func testFragmentedPingIsIgnored() throws {
        // A fragmented ping (fin = false) is illegal per RFC 6455 §5.5 and must be dropped.
        let buffer = channel.allocator.buffer(capacity: 0)
        let frame = WebSocketFrame(fin: false, opcode: .ping, maskKey: nil, data: buffer)
        try channel.writeInbound(frame)

        XCTAssertNil(
            try channel.readOutbound(as: WebSocketFrame.self),
            "Fragmented ping must not produce a pong"
        )
    }

    // MARK: - Connection-close echo (RFC 6455 §5.5.1)

    func testConnectionCloseEchosCloseFrame() throws {
        var buffer = channel.allocator.buffer(capacity: 2)
        buffer.write(webSocketErrorCode: .normalClosure)
        let frame = WebSocketFrame(fin: true, opcode: .connectionClose, maskKey: nil, data: buffer)
        try channel.writeInbound(frame)

        let echo = try XCTUnwrap(channel.readOutbound(as: WebSocketFrame.self))
        XCTAssertEqual(echo.opcode, .connectionClose)
    }

    func testDuplicateConnectionCloseIsIgnored() throws {
        var buffer = channel.allocator.buffer(capacity: 2)
        buffer.write(webSocketErrorCode: .normalClosure)
        let frame = WebSocketFrame(fin: true, opcode: .connectionClose, maskKey: nil, data: buffer)
        // Send first close.
        try channel.writeInbound(frame)
        _ = try channel.readOutbound(as: WebSocketFrame.self) // consume echo

        // Send second close — must be a no-op (awaitingClose guard).
        try channel.writeInbound(frame)
        XCTAssertNil(
            try channel.readOutbound(as: WebSocketFrame.self),
            "Second close frame must not produce another echo"
        )
    }

    // MARK: - channelInactive finishes message stream

    func testChannelInactiveFinishesMessageStream() {
        // Channel operation stays on the test thread.
        channel.pipeline.fireChannelInactive()

        let exp = expectation(description: "stream finishes after channelInactive")
        let ws = webSocket!
        Task {
            var iterator = ws.messages.makeAsyncIterator()
            let message = await iterator.next()
            XCTAssertNil(message, "AsyncStream must finish (yield nil) after channelInactive")
            exp.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    // MARK: - errorCaught finishes message stream

    func testErrorCaughtFinishesMessageStream() {
        struct TestError: Error {}
        // Channel operation stays on the test thread.
        channel.pipeline.fireErrorCaught(TestError())

        let exp = expectation(description: "stream finishes after errorCaught")
        let ws = webSocket!
        Task {
            var iterator = ws.messages.makeAsyncIterator()
            let message = await iterator.next()
            XCTAssertNil(message, "AsyncStream must finish (yield nil) after errorCaught")
            exp.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    // MARK: - Continuation and pong frames are discarded

    func testContinuationFrameIsDiscarded() throws {
        let buffer = channel.allocator.buffer(capacity: 0)
        let frame = WebSocketFrame(fin: true, opcode: .continuation, maskKey: nil, data: buffer)
        try channel.writeInbound(frame)

        // No outbound frame should be produced.
        XCTAssertNil(try channel.readOutbound(as: WebSocketFrame.self))
    }

    func testPongFrameIsDiscarded() throws {
        let buffer = channel.allocator.buffer(capacity: 0)
        let frame = WebSocketFrame(fin: true, opcode: .pong, maskKey: nil, data: buffer)
        try channel.writeInbound(frame)

        XCTAssertNil(try channel.readOutbound(as: WebSocketFrame.self))
    }
}
