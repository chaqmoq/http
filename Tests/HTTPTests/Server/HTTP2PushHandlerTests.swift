@testable import HTTP
import NIO
import NIOHTTP2
import XCTest

/// Unit tests for `HTTP2PushHandler` using a synchronous `EmbeddedChannel`.
///
/// Because there is no real HTTP/2 multiplexer present, `sendPushes` always
/// returns a pre-resolved future (the `parent?.pipeline` guard returns early).
/// This lets us verify the pass-through and deferral behaviour synchronously,
/// using `channel.embeddedEventLoop.run()` to drain any scheduled callbacks.
final class HTTP2PushHandlerTests: XCTestCase {
    private var handler: HTTP2PushHandler!
    private var channel: EmbeddedChannel!

    override func setUp() {
        super.setUp()
        handler = HTTP2PushHandler()
        channel = EmbeddedChannel()
        try! channel.pipeline.addHandler(handler).wait()
    }

    override func tearDown() {
        _ = try? channel.finish()
        super.tearDown()
    }

    // MARK: - Inbound pass-through

    func testChannelReadFiresThrough() throws {
        let payload = makeDataPayload(endStream: false)
        try channel.writeInbound(payload)

        // The frame must be visible to the next inbound handler (EmbeddedChannel tail).
        let inbound = try XCTUnwrap(channel.readInbound(as: HTTP2Frame.FramePayload.self))
        guard case .data = inbound else {
            return XCTFail("Expected .data inbound, got \(inbound)")
        }
    }

    // MARK: - Outbound pass-through (no pushes queued)

    func testWritePassesThroughWhenNoPushesQueued() throws {
        let payload = makeDataPayload(endStream: true)
        channel.write(payload, promise: nil)
        channel.flush()

        let out = try XCTUnwrap(channel.readOutbound(as: HTTP2Frame.FramePayload.self))
        guard case .data = out else {
            return XCTFail("Expected .data outbound, got \(out)")
        }
    }

    func testFlushFiresThrough() throws {
        // Flushing without a prior write must not crash or drop anything.
        // This exercises the `flush(context:)` pass-through.
        channel.flush()
        XCTAssertNil(try channel.readOutbound(as: HTTP2Frame.FramePayload.self))
    }

    // MARK: - enqueue / pushesHandled

    func testEnqueueStoresPushes() {
        let uri = URI("/style.css")!
        let response = Response(Body(string: "body { }"))
        handler.enqueue([(uri: uri, response: response)], authority: "example.com")

        // Verify by triggering a write and confirming the push path was taken:
        // with no parent multiplexer, sendPushes() returns immediately, so the
        // deferred main frame must still be forwarded after embeddedEventLoop.run().
        let payload = makeDataPayload(endStream: true)
        channel.write(payload, promise: nil)
        channel.flush()
        channel.embeddedEventLoop.run()

        XCTAssertNotNil(
            try? channel.readOutbound(as: HTTP2Frame.FramePayload.self),
            "Main response frame should be forwarded after push path completes"
        )
    }

    func testEnqueueResetsHandledFlag() {
        let uri = URI("/a.css")!

        // First enqueue + write: uses up the pending pushes.
        handler.enqueue([(uri: uri, response: Response("css"))], authority: "localhost")
        let p1 = makeDataPayload(endStream: false)
        channel.write(p1, promise: nil)
        channel.flush()
        channel.embeddedEventLoop.run()
        while (try? channel.readOutbound(as: HTTP2Frame.FramePayload.self)) != nil {}

        // Second enqueue resets the handler so the next write goes through the push path again.
        handler.enqueue([(uri: URI("/b.js")!, response: Response("js"))], authority: "localhost")
        let p2 = makeDataPayload(endStream: true)
        channel.write(p2, promise: nil)
        channel.flush()
        channel.embeddedEventLoop.run()

        XCTAssertNotNil(
            try? channel.readOutbound(as: HTTP2Frame.FramePayload.self),
            "After a second enqueue the main frame must still be forwarded"
        )
    }

    // MARK: - pushesHandled prevents double-sending

    func testSubsequentWritesPassThroughImmediately() throws {
        handler.enqueue([(uri: URI("/x.js")!, response: Response("js"))], authority: "localhost")

        // First write: enters push path (no-op without multiplexer).
        let p1 = makeDataPayload(endStream: false)
        channel.write(p1, promise: nil)
        channel.flush()
        channel.embeddedEventLoop.run()
        _ = try channel.readOutbound(as: HTTP2Frame.FramePayload.self) // drain first frame

        // Second write (e.g. a trailing DATA/END_STREAM frame):
        // pushesHandled is now true, so this write must be forwarded synchronously
        // without going through the push logic again.
        let p2 = makeDataPayload(endStream: true)
        channel.write(p2, promise: nil)
        channel.flush()
        // No embeddedEventLoop.run() needed — the frame should be available immediately.

        XCTAssertNotNil(
            try channel.readOutbound(as: HTTP2Frame.FramePayload.self),
            "Subsequent write must pass through immediately once pushesHandled is true"
        )
    }

    // MARK: - No pushes: write does not go through deferred path

    func testWriteIsForwardedSynchronouslyWhenNoPushes() throws {
        // When there are no pending pushes the write must not be deferred through the
        // event loop — it goes straight through the context.write() call path.
        let payload = makeDataPayload(endStream: true)
        channel.write(payload, promise: nil)
        channel.flush()
        // Do NOT call embeddedEventLoop.run(); the frame must already be available.

        XCTAssertNotNil(
            try channel.readOutbound(as: HTTP2Frame.FramePayload.self),
            "Write must be forwarded synchronously when no pushes are pending"
        )
    }
}

// MARK: - Helpers

extension HTTP2PushHandlerTests {
    private func makeDataPayload(endStream: Bool) -> HTTP2Frame.FramePayload {
        let buf = ByteBufferAllocator().buffer(capacity: 0)
        return .data(.init(data: .byteBuffer(buf), endStream: endStream))
    }
}

// MARK: - PushResponseEncoder unit tests

/// `PushResponseEncoder` is the internal ChannelOutboundHandler used by
/// `HTTP2PushHandler.sendOnePush` to convert a `Response` into the
/// `HTTP2Frame.FramePayload` sequence expected by a server-push stream channel.
final class PushResponseEncoderTests: XCTestCase {
    private var encoderChannel: EmbeddedChannel!

    override func setUp() {
        super.setUp()
        encoderChannel = EmbeddedChannel()
        try! encoderChannel.pipeline.addHandler(PushResponseEncoder()).wait()
    }

    override func tearDown() {
        _ = try? encoderChannel.finish()
        super.tearDown()
    }

    // MARK: - Empty-body response

    /// An empty response should emit a single HEADERS frame with `endStream = true`.
    /// No DATA frame should follow.
    func testEmptyBodyEmitsSingleHeadersFrameWithEndStream() throws {
        let response = Response(status: .ok)
        encoderChannel.write(response, promise: nil)
        encoderChannel.flush()

        // Frame 1 must be a HEADERS frame with endStream = true.
        let frame1 = try XCTUnwrap(encoderChannel.readOutbound(as: HTTP2Frame.FramePayload.self))
        guard case .headers(let headersPayload) = frame1 else {
            return XCTFail("Expected .headers frame, got \(frame1)")
        }
        XCTAssertTrue(headersPayload.endStream, "HEADERS frame must carry endStream=true for empty body")

        // :status pseudo-header must reflect the response status code.
        let statusValue = headersPayload.headers.first(where: { $0.name == ":status" })?.value
        XCTAssertEqual(statusValue, "200")

        // No DATA frame should follow.
        XCTAssertNil(
            try encoderChannel.readOutbound(as: HTTP2Frame.FramePayload.self),
            "No DATA frame expected for empty body"
        )
    }

    // MARK: - Non-empty-body response

    /// A response with a body should emit a HEADERS frame (`endStream = false`)
    /// followed by a DATA frame (`endStream = true`).
    func testNonEmptyBodyEmitsHeadersThenData() throws {
        let body = Body(string: "server push payload")
        let response = Response(body, status: .ok)
        encoderChannel.write(response, promise: nil)
        encoderChannel.flush()

        // Frame 1: HEADERS with endStream = false (body follows).
        let frame1 = try XCTUnwrap(encoderChannel.readOutbound(as: HTTP2Frame.FramePayload.self))
        guard case .headers(let headersPayload) = frame1 else {
            return XCTFail("Expected .headers frame 1, got \(frame1)")
        }
        XCTAssertFalse(headersPayload.endStream, "HEADERS frame must carry endStream=false when body is present")

        let statusValue = headersPayload.headers.first(where: { $0.name == ":status" })?.value
        XCTAssertEqual(statusValue, "200")

        // Frame 2: DATA with endStream = true.
        let frame2 = try XCTUnwrap(encoderChannel.readOutbound(as: HTTP2Frame.FramePayload.self))
        guard case .data(let dataPayload) = frame2 else {
            return XCTFail("Expected .data frame 2, got \(frame2)")
        }
        XCTAssertTrue(dataPayload.endStream, "DATA frame must carry endStream=true")

        // No further frames.
        XCTAssertNil(
            try encoderChannel.readOutbound(as: HTTP2Frame.FramePayload.self),
            "No further frames expected after DATA"
        )
    }

    // MARK: - Response headers are forwarded

    /// Regular response headers (non-pseudo) must be included in the HEADERS frame.
    func testResponseHeadersAreForwardedToHPACKHeaders() throws {
        var response = Response(status: .created)
        response.headers.set(.init(name: .contentType, value: "application/json"))
        encoderChannel.write(response, promise: nil)
        encoderChannel.flush()

        let frame = try XCTUnwrap(encoderChannel.readOutbound(as: HTTP2Frame.FramePayload.self))
        guard case .headers(let headersPayload) = frame else {
            return XCTFail("Expected .headers frame, got \(frame)")
        }

        let statusValue = headersPayload.headers.first(where: { $0.name == ":status" })?.value
        XCTAssertEqual(statusValue, "201")

        let ctValue = headersPayload.headers.first(where: { $0.name == "content-type" })?.value
        XCTAssertEqual(ctValue, "application/json")
    }
}
