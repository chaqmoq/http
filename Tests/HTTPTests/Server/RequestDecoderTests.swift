@testable import HTTP
import NIO
import NIOHTTP1
import XCTest

/// Unit tests for `RequestDecoder` using a synchronous `EmbeddedChannel`.
///
/// Each test drives the decoder by writing `HTTPServerRequestPart` values directly
/// into the inbound side of the pipeline and reads the resulting `Request` (or
/// captures channel errors) without needing a live TCP connection.
final class RequestDecoderTests: XCTestCase {
    // Retain decoder and error capture so tests can inspect state directly.
    private var decoder: RequestDecoder!
    private var errorCapture: DecoderErrorCapture!
    private var channel: EmbeddedChannel!

    override func setUp() {
        super.setUp()
        decoder = RequestDecoder()
        errorCapture = DecoderErrorCapture()
        channel = EmbeddedChannel()
        try! channel.pipeline.addHandlers([decoder, errorCapture]).wait()
    }

    override func tearDown() {
        _ = try? channel.finish()
        super.tearDown()
    }

    // MARK: - Head field parsing

    func testDecodesMethod() throws {
        let head = HTTPRequestHead(version: .http1_1, method: .DELETE, uri: "/users/1")
        try channel.writeInbound(HTTPServerRequestPart.head(head))
        try channel.writeInbound(HTTPServerRequestPart.end(nil))

        let req = try XCTUnwrap(channel.readInbound(as: Request.self))
        XCTAssertEqual(req.method, .DELETE)
    }

    func testDecodesURI() throws {
        let head = HTTPRequestHead(version: .http1_1, method: .GET, uri: "/api/v1/posts?page=2")
        try channel.writeInbound(HTTPServerRequestPart.head(head))
        try channel.writeInbound(HTTPServerRequestPart.end(nil))

        let req = try XCTUnwrap(channel.readInbound(as: Request.self))
        XCTAssertEqual(req.uri.path, "/api/v1/posts")
    }

    func testDecodesVersion() throws {
        let head = HTTPRequestHead(version: .http1_0, method: .GET, uri: "/")
        try channel.writeInbound(HTTPServerRequestPart.head(head))
        try channel.writeInbound(HTTPServerRequestPart.end(nil))

        let req = try XCTUnwrap(channel.readInbound(as: Request.self))
        XCTAssertEqual(req.version.major, 1)
        XCTAssertEqual(req.version.minor, 0)
    }

    func testDecodesHeaders() throws {
        let head = HTTPRequestHead(
            version: .http1_1,
            method: .POST,
            uri: "/",
            headers: HTTPHeaders([
                ("content-type", "application/json"),
                ("authorization", "Bearer secret")
            ])
        )
        try channel.writeInbound(HTTPServerRequestPart.head(head))
        try channel.writeInbound(HTTPServerRequestPart.end(nil))

        let req = try XCTUnwrap(channel.readInbound(as: Request.self))
        XCTAssertEqual(req.headers.get(.contentType), "application/json")
        XCTAssertEqual(req.headers.get(.authorization), "Bearer secret")
    }

    // MARK: - Body accumulation

    func testEmptyBodyIsNotSet() throws {
        let head = HTTPRequestHead(version: .http1_1, method: .GET, uri: "/")
        try channel.writeInbound(HTTPServerRequestPart.head(head))
        try channel.writeInbound(HTTPServerRequestPart.end(nil))

        let req = try XCTUnwrap(channel.readInbound(as: Request.self))
        XCTAssertTrue(req.body.isEmpty)
    }

    func testDecodesSingleBodyChunk() throws {
        let head = HTTPRequestHead(version: .http1_1, method: .POST, uri: "/")
        var buf = ByteBufferAllocator().buffer(capacity: 11)
        buf.writeString("hello world")

        try channel.writeInbound(HTTPServerRequestPart.head(head))
        try channel.writeInbound(HTTPServerRequestPart.body(buf))
        try channel.writeInbound(HTTPServerRequestPart.end(nil))

        let req = try XCTUnwrap(channel.readInbound(as: Request.self))
        XCTAssertEqual(req.body.string, "hello world")
        XCTAssertEqual(req.body.count, 11)
    }

    func testAccumulatesMultipleBodyChunks() throws {
        let head = HTTPRequestHead(version: .http1_1, method: .POST, uri: "/")
        var c1 = ByteBufferAllocator().buffer(capacity: 3); c1.writeString("foo")
        var c2 = ByteBufferAllocator().buffer(capacity: 3); c2.writeString("bar")
        var c3 = ByteBufferAllocator().buffer(capacity: 3); c3.writeString("baz")

        try channel.writeInbound(HTTPServerRequestPart.head(head))
        try channel.writeInbound(HTTPServerRequestPart.body(c1))
        try channel.writeInbound(HTTPServerRequestPart.body(c2))
        try channel.writeInbound(HTTPServerRequestPart.body(c3))
        try channel.writeInbound(HTTPServerRequestPart.end(nil))

        let req = try XCTUnwrap(channel.readInbound(as: Request.self))
        XCTAssertEqual(req.body.string, "foobarbaz")
        XCTAssertEqual(req.body.count, 9)
    }

    func testBodyBytesAreExact() throws {
        // Verify ByteBuffer round-trip: body bytes must exactly match the input.
        let input: [UInt8] = [0x00, 0x01, 0x02, 0xFF, 0xFE]
        let head = HTTPRequestHead(version: .http1_1, method: .PUT, uri: "/")
        var buf = ByteBufferAllocator().buffer(capacity: input.count)
        buf.writeBytes(input)

        try channel.writeInbound(HTTPServerRequestPart.head(head))
        try channel.writeInbound(HTTPServerRequestPart.body(buf))
        try channel.writeInbound(HTTPServerRequestPart.end(nil))

        let req = try XCTUnwrap(channel.readInbound(as: Request.self))
        XCTAssertEqual(req.body.bytes, input)
    }

    // MARK: - State machine

    func testStateIsIdleInitially() {
        guard case .idle = decoder.state else {
            return XCTFail("Expected .idle state initially, got \(decoder.state)")
        }
    }

    func testStateIsDecodingAfterHead() throws {
        let head = HTTPRequestHead(version: .http1_1, method: .GET, uri: "/")
        try channel.writeInbound(HTTPServerRequestPart.head(head))

        guard case .decoding = decoder.state else {
            return XCTFail("Expected .decoding after .head, got \(decoder.state)")
        }
    }

    func testStateIsIdleAfterEnd() throws {
        let head = HTTPRequestHead(version: .http1_1, method: .GET, uri: "/")
        try channel.writeInbound(HTTPServerRequestPart.head(head))
        try channel.writeInbound(HTTPServerRequestPart.end(nil))
        _ = try channel.readInbound(as: Request.self)

        guard case .idle = decoder.state else {
            return XCTFail("Expected .idle after .end, got \(decoder.state)")
        }
    }

    func testSecondRequestDecodedAfterFirstCompletes() throws {
        // Decoder must reset to .idle and accept a second request on the same channel.
        let head1 = HTTPRequestHead(version: .http1_1, method: .GET, uri: "/first")
        try channel.writeInbound(HTTPServerRequestPart.head(head1))
        try channel.writeInbound(HTTPServerRequestPart.end(nil))
        _ = try channel.readInbound(as: Request.self)

        let head2 = HTTPRequestHead(version: .http1_1, method: .POST, uri: "/second")
        try channel.writeInbound(HTTPServerRequestPart.head(head2))
        try channel.writeInbound(HTTPServerRequestPart.end(nil))

        let req2 = try XCTUnwrap(channel.readInbound(as: Request.self))
        XCTAssertEqual(req2.uri.path, "/second")
    }

    // MARK: - maxBodySize enforcement

    func testBodyAtLimitIsAccepted() throws {
        let localDecoder = RequestDecoder(maxBodySize: 5)
        let localCapture = DecoderErrorCapture()
        let localChannel = EmbeddedChannel()
        try localChannel.pipeline.addHandlers([localDecoder, localCapture]).wait()
        defer { _ = try? localChannel.finish() }

        let head = HTTPRequestHead(version: .http1_1, method: .POST, uri: "/")
        var body = ByteBufferAllocator().buffer(capacity: 5)
        body.writeString("hello") // 5 bytes == limit 5

        try localChannel.writeInbound(HTTPServerRequestPart.head(head))
        try localChannel.writeInbound(HTTPServerRequestPart.body(body))
        try localChannel.writeInbound(HTTPServerRequestPart.end(nil))

        XCTAssertTrue(localCapture.errors.isEmpty, "No error expected at exactly the limit")
        let req = try XCTUnwrap(localChannel.readInbound(as: Request.self))
        XCTAssertEqual(req.body.string, "hello")
    }

    func testBodyExceedingLimitFiresBodyTooLargeError() throws {
        let localDecoder = RequestDecoder(maxBodySize: 4)
        let localCapture = DecoderErrorCapture()
        let localChannel = EmbeddedChannel()
        try localChannel.pipeline.addHandlers([localDecoder, localCapture]).wait()
        defer { _ = try? localChannel.finish() }

        let head = HTTPRequestHead(version: .http1_1, method: .POST, uri: "/")
        var body = ByteBufferAllocator().buffer(capacity: 5)
        body.writeString("hello") // 5 bytes > limit 4

        try localChannel.writeInbound(HTTPServerRequestPart.head(head))
        try localChannel.writeInbound(HTTPServerRequestPart.body(body))

        XCTAssertFalse(localCapture.errors.isEmpty, "Expected a bodyTooLarge error")
        XCTAssertTrue(
            localCapture.errors.first is ServerError,
            "Expected ServerError, got \(String(describing: localCapture.errors.first))"
        )
    }

    func testBodyTooLargeResetsStateToIdle() throws {
        let localDecoder = RequestDecoder(maxBodySize: 4)
        let localCapture = DecoderErrorCapture()
        let localChannel = EmbeddedChannel()
        try localChannel.pipeline.addHandlers([localDecoder, localCapture]).wait()
        defer { _ = try? localChannel.finish() }

        let head = HTTPRequestHead(version: .http1_1, method: .POST, uri: "/")
        var body = ByteBufferAllocator().buffer(capacity: 5)
        body.writeString("hello")

        try localChannel.writeInbound(HTTPServerRequestPart.head(head))
        try localChannel.writeInbound(HTTPServerRequestPart.body(body))

        guard case .idle = localDecoder.state else {
            return XCTFail("Expected .idle after bodyTooLarge, got \(localDecoder.state)")
        }
    }

    // MARK: - Protocol violations

    func testBodyBeforeHeadFiresError() throws {
        var body = ByteBufferAllocator().buffer(capacity: 4)
        body.writeString("oops")

        try channel.writeInbound(HTTPServerRequestPart.body(body))

        XCTAssertFalse(
            errorCapture.errors.isEmpty,
            "Expected a protocol-violation error for .body before .head"
        )
    }

    func testEndBeforeHeadFiresError() throws {
        try channel.writeInbound(HTTPServerRequestPart.end(nil))

        XCTAssertFalse(
            errorCapture.errors.isEmpty,
            "Expected a protocol-violation error for .end before .head"
        )
    }

    func testDoubleHeadFiresError() throws {
        let head = HTTPRequestHead(version: .http1_1, method: .GET, uri: "/")
        try channel.writeInbound(HTTPServerRequestPart.head(head))
        try channel.writeInbound(HTTPServerRequestPart.head(head)) // second .head

        XCTAssertFalse(
            errorCapture.errors.isEmpty,
            "Expected a protocol-violation error for a second .head"
        )
    }
}

// MARK: - Error capture helper

/// Sits after `RequestDecoder` and collects any errors fired into the pipeline,
/// forwarding all other inbound events unchanged so `channel.readInbound` still works.
private final class DecoderErrorCapture: ChannelInboundHandler {
    typealias InboundIn = NIOAny

    var errors: [Error] = []

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        context.fireChannelRead(data)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        errors.append(error)
    }
}
