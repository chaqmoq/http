@preconcurrency @testable import HTTP
import NIO
import NIOHTTP1
import XCTest

/// Unit tests for ``BodyStream`` and the streaming paths of ``RequestDecoder``.
final class BodyStreamTests: XCTestCase {

    // MARK: - BodyStream.collect

    func testCollectAssemblesChunksInOrder() async throws {
        let stream = BodyStream()

        var buf1 = ByteBufferAllocator().buffer(capacity: 3); buf1.writeString("foo")
        var buf2 = ByteBufferAllocator().buffer(capacity: 3); buf2.writeString("bar")
        var buf3 = ByteBufferAllocator().buffer(capacity: 3); buf3.writeString("baz")

        stream.yield(buf1)
        stream.yield(buf2)
        stream.yield(buf3)
        stream.finish()

        let body = try await stream.collect()
        XCTAssertEqual(body.string, "foobarbaz")
        XCTAssertEqual(body.count, 9)
    }

    func testCollectEmptyStreamReturnsEmptyBody() async throws {
        let stream = BodyStream()
        stream.finish()

        let body = try await stream.collect()
        XCTAssertTrue(body.isEmpty)
    }

    func testCollectSingleChunkBody() async throws {
        let stream = BodyStream()
        var buf = ByteBufferAllocator().buffer(capacity: 5); buf.writeString("hello")
        stream.yield(buf)
        stream.finish()

        let body = try await stream.collect()
        XCTAssertEqual(body.string, "hello")
    }

    // MARK: - maxSize enforcement

    func testCollectThrowsTooLargeWhenLimitExceeded() async throws {
        let stream = BodyStream()
        var buf = ByteBufferAllocator().buffer(capacity: 5); buf.writeString("hello")
        stream.yield(buf)
        stream.finish()

        do {
            _ = try await stream.collect(maxSize: 4)
            XCTFail("Expected BodyStreamError.tooLarge to be thrown")
        } catch BodyStreamError.tooLarge {
            // expected
        }
    }

    func testCollectAtExactLimitSucceeds() async throws {
        let stream = BodyStream()
        var buf = ByteBufferAllocator().buffer(capacity: 5); buf.writeString("hello")
        stream.yield(buf)
        stream.finish()

        // maxSize == body size → should NOT throw
        let body = try await stream.collect(maxSize: 5)
        XCTAssertEqual(body.count, 5)
    }

    func testCollectLimitEnforcedAcrossMultipleChunks() async throws {
        let stream = BodyStream()
        // Two 4-byte chunks → total 8 bytes. Limit is 7 → should throw on second chunk.
        var c1 = ByteBufferAllocator().buffer(capacity: 4); c1.writeString("abcd")
        var c2 = ByteBufferAllocator().buffer(capacity: 4); c2.writeString("efgh")
        stream.yield(c1)
        stream.yield(c2)
        stream.finish()

        do {
            _ = try await stream.collect(maxSize: 7)
            XCTFail("Expected BodyStreamError.tooLarge")
        } catch BodyStreamError.tooLarge {
            // expected
        }
    }

    // MARK: - Error propagation

    func testFinishWithErrorPropagatesViaIteration() async throws {
        struct TestError: Error, Equatable {}
        let stream = BodyStream()
        stream.finish(throwing: TestError())

        do {
            _ = try await stream.collect()
            XCTFail("Expected TestError to be thrown")
        } catch is TestError {
            // expected
        }
    }

    // MARK: - Request.collectBody

    func testCollectBodyInBufferedModeReturnsSameBody() async throws {
        let eventLoop = EmbeddedEventLoop()
        var request = Request(
            eventLoop: eventLoop,
            body: Body(string: "buffered payload")
        )

        let body = try await request.collectBody()

        XCTAssertEqual(body.string, "buffered payload")
        XCTAssertNil(request.bodyStream, "bodyStream should remain nil in buffered mode")
    }

    func testCollectBodyInStreamingModeAssemblesAndCachesBody() async throws {
        let eventLoop = EmbeddedEventLoop()
        let stream = BodyStream()
        var request = Request(eventLoop: eventLoop)
        request.bodyStream = stream

        var buf = ByteBufferAllocator().buffer(capacity: 7); buf.writeString("streamed")
        stream.yield(buf)
        stream.finish()

        let body = try await request.collectBody()

        XCTAssertEqual(body.string, "streamed")
        // After collect, body is cached and bodyStream is cleared.
        XCTAssertEqual(request.body.string, "streamed")
        XCTAssertNil(request.bodyStream, "bodyStream should be nil after collection")
    }

    func testCollectBodySecondCallIsFreeAfterCaching() async throws {
        let eventLoop = EmbeddedEventLoop()
        let stream = BodyStream()
        var request = Request(eventLoop: eventLoop)
        request.bodyStream = stream

        var buf = ByteBufferAllocator().buffer(capacity: 2); buf.writeString("hi")
        stream.yield(buf)
        stream.finish()

        _ = try await request.collectBody()

        // Second call operates on the buffered body — no stream work, no throw.
        let second = try await request.collectBody()
        XCTAssertEqual(second.string, "hi")
    }

    // MARK: - BodyStreamError description

    func testBodyStreamErrorTooLargeDescription() {
        XCTAssertEqual(
            BodyStreamError.tooLarge.description,
            "Body stream exceeded the maximum allowed size."
        )
    }

    func testCollectBodyRespectsMaxSizeInStreamingMode() async throws {
        let eventLoop = EmbeddedEventLoop()
        let stream = BodyStream()
        var request = Request(eventLoop: eventLoop)
        request.bodyStream = stream

        var buf = ByteBufferAllocator().buffer(capacity: 10); buf.writeString("0123456789")
        stream.yield(buf)
        stream.finish()

        do {
            _ = try await request.collectBody(maxSize: 5)
            XCTFail("Expected BodyStreamError.tooLarge")
        } catch BodyStreamError.tooLarge {
            // expected
        }
    }
}

// MARK: - RequestDecoder streaming mode tests

final class RequestDecoderStreamingTests: XCTestCase {

    // MARK: - Streaming threshold

    func testBelowThresholdUsesBufferedMode() async throws {
        // Content-Length 5, threshold 10 → buffered
        let decoder = RequestDecoder(streamingBodyThreshold: 10)
        let channel = EmbeddedChannel()
        try await channel.pipeline.addHandler(decoder).get()
        defer { _ = try? channel.finish() }

        let head = HTTPRequestHead(
            version: .http1_1,
            method: .POST,
            uri: "/",
            headers: HTTPHeaders([("content-length", "5")])
        )
        var body = ByteBufferAllocator().buffer(capacity: 5); body.writeString("hello")

        try channel.writeInbound(HTTPServerRequestPart.head(head))
        // No request fired yet — waiting for .end
        XCTAssertNil(try channel.readInbound(as: Request.self))

        try channel.writeInbound(HTTPServerRequestPart.body(body))
        try channel.writeInbound(HTTPServerRequestPart.end(nil))

        let req = try XCTUnwrap(channel.readInbound(as: Request.self))
        XCTAssertNil(req.bodyStream, "bodyStream should be nil in buffered mode")
        XCTAssertEqual(req.body.string, "hello")
    }

    func testAboveThresholdUsesStreamingMode() async throws {
        // Content-Length 11, threshold 5 → streaming
        let decoder = RequestDecoder(streamingBodyThreshold: 5)
        let channel = EmbeddedChannel()
        try await channel.pipeline.addHandler(decoder).get()
        defer { _ = try? channel.finish() }

        let head = HTTPRequestHead(
            version: .http1_1,
            method: .POST,
            uri: "/",
            headers: HTTPHeaders([("content-length", "11")])
        )

        try channel.writeInbound(HTTPServerRequestPart.head(head))

        // Request must be available immediately after .head
        let req = try XCTUnwrap(channel.readInbound(as: Request.self))
        XCTAssertNotNil(req.bodyStream, "bodyStream should be non-nil in streaming mode")
        XCTAssertTrue(req.body.isEmpty, "body should be empty before streaming starts")
    }

    func testUnknownContentLengthAlwaysStreamsWhenThresholdSet() async throws {
        // No Content-Length header → unknown length → always stream when threshold is set
        let decoder = RequestDecoder(streamingBodyThreshold: 0)
        let channel = EmbeddedChannel()
        try await channel.pipeline.addHandler(decoder).get()
        defer { _ = try? channel.finish() }

        let head = HTTPRequestHead(version: .http1_1, method: .POST, uri: "/")

        try channel.writeInbound(HTTPServerRequestPart.head(head))

        let req = try XCTUnwrap(channel.readInbound(as: Request.self))
        XCTAssertNotNil(req.bodyStream)
    }

    func testNoThresholdAlwaysBuffers() async throws {
        // streamingBodyThreshold == nil → always buffer regardless of size
        let decoder = RequestDecoder(streamingBodyThreshold: nil)
        let channel = EmbeddedChannel()
        try await channel.pipeline.addHandler(decoder).get()
        defer { _ = try? channel.finish() }

        let head = HTTPRequestHead(
            version: .http1_1,
            method: .POST,
            uri: "/",
            headers: HTTPHeaders([("content-length", "1000000")])
        )

        try channel.writeInbound(HTTPServerRequestPart.head(head))
        // No request emitted yet — still collecting
        XCTAssertNil(try channel.readInbound(as: Request.self))
    }

    // MARK: - Stream content delivery

    /// `AsyncThrowingStream` buffers yielded elements when no consumer is active, so we
    /// can write all chunks synchronously first and then drain with `async throws` collect.
    func testStreamReceivesAllChunksInOrder() async throws {
        let decoder = RequestDecoder(streamingBodyThreshold: 0)
        let channel = EmbeddedChannel()
        try await channel.pipeline.addHandler(decoder).get()
        defer { _ = try? channel.finish() }

        let head = HTTPRequestHead(version: .http1_1, method: .POST, uri: "/")
        var c1 = ByteBufferAllocator().buffer(capacity: 3); c1.writeString("foo")
        var c2 = ByteBufferAllocator().buffer(capacity: 3); c2.writeString("bar")

        try channel.writeInbound(HTTPServerRequestPart.head(head))
        let req = try XCTUnwrap(channel.readInbound(as: Request.self))
        let stream = try XCTUnwrap(req.bodyStream)

        // Write all chunks before awaiting — the stream buffers them.
        try channel.writeInbound(HTTPServerRequestPart.body(c1))
        try channel.writeInbound(HTTPServerRequestPart.body(c2))
        try channel.writeInbound(HTTPServerRequestPart.end(nil))

        let body = try await stream.collect()
        XCTAssertEqual(body.string, "foobar")
    }

    func testStreamIsFinishedOnEnd() async throws {
        let decoder = RequestDecoder(streamingBodyThreshold: 0)
        let channel = EmbeddedChannel()
        try await channel.pipeline.addHandler(decoder).get()
        defer { _ = try? channel.finish() }

        let head = HTTPRequestHead(version: .http1_1, method: .POST, uri: "/")
        try channel.writeInbound(HTTPServerRequestPart.head(head))
        let req = try XCTUnwrap(channel.readInbound(as: Request.self))
        let stream = try XCTUnwrap(req.bodyStream)

        try channel.writeInbound(HTTPServerRequestPart.end(nil))

        let body = try await stream.collect()
        XCTAssertTrue(body.isEmpty)
    }

    // MARK: - maxBodySize in streaming mode

    func testStreamingMaxBodySizeFinishesStreamWithError() async throws {
        // maxBodySize = 4, body = 5 bytes → stream.finish(throwing:) is called
        let decoder = RequestDecoder(maxBodySize: 4, streamingBodyThreshold: 0)
        let capture = DecoderErrorCaptureStreaming()
        let channel = EmbeddedChannel()
        try await channel.pipeline.addHandlers([decoder, capture]).get()
        defer { _ = try? channel.finish() }

        let head = HTTPRequestHead(version: .http1_1, method: .POST, uri: "/")
        var body = ByteBufferAllocator().buffer(capacity: 5); body.writeString("hello")

        try channel.writeInbound(HTTPServerRequestPart.head(head))
        let req = try XCTUnwrap(channel.readInbound(as: Request.self))
        let stream = try XCTUnwrap(req.bodyStream)

        // Exceeds maxBodySize → RequestDecoder calls stream.finish(throwing: ServerError.bodyTooLarge)
        try channel.writeInbound(HTTPServerRequestPart.body(body))

        do {
            _ = try await stream.collect()
            XCTFail("Expected ServerError.bodyTooLarge to be thrown from the stream")
        } catch is ServerError {
            // expected
        }
    }

    // MARK: - State machine in streaming mode

    func testStateIsStreamingAfterHeadWithThreshold() async throws {
        let decoder = RequestDecoder(streamingBodyThreshold: 0)
        let channel = EmbeddedChannel()
        try await channel.pipeline.addHandler(decoder).get()
        defer { _ = try? channel.finish() }

        let head = HTTPRequestHead(version: .http1_1, method: .POST, uri: "/")
        try channel.writeInbound(HTTPServerRequestPart.head(head))

        guard case .streaming = decoder.state else {
            return XCTFail("Expected .streaming state after head with threshold, got \(decoder.state)")
        }
    }

    func testStateIsIdleAfterStreamingEnd() async throws {
        let decoder = RequestDecoder(streamingBodyThreshold: 0)
        let channel = EmbeddedChannel()
        try await channel.pipeline.addHandler(decoder).get()
        defer { _ = try? channel.finish() }

        let head = HTTPRequestHead(version: .http1_1, method: .POST, uri: "/")
        try channel.writeInbound(HTTPServerRequestPart.head(head))
        _ = try channel.readInbound(as: Request.self)
        try channel.writeInbound(HTTPServerRequestPart.end(nil))

        guard case .idle = decoder.state else {
            return XCTFail("Expected .idle after .end in streaming mode, got \(decoder.state)")
        }
    }
}

// MARK: - Error capture helper (used by streaming decoder tests)

private final class DecoderErrorCaptureStreaming: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = NIOAny

    var errors: [Error] = []

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        context.fireChannelRead(data)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        errors.append(error)
    }
}
