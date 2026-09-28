import AsyncHTTPClient
@testable import HTTP
import NIO
import NIOHTTP1
import XCTest

private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

/// Integration tests for streamed (`Response(stream:)`) responses.
///
/// The server runs on a background thread so a broken stream fails the test by timing out instead
/// of hanging it: `Server.start()` blocks until the server stops.
final class ResponseStreamTests: XCTestCase, @unchecked Sendable {
    var client: HTTPClient!
    var server: Server!

    override func setUp() {
        super.setUp()
        client = HTTPClient(eventLoopGroupProvider: .singleton)
        server = Server(configuration: .init(port: 8093, numberOfThreads: 1))
    }

    override func tearDown() {
        try? client.syncShutdown()
        try? server.stop()
        super.tearDown()
    }

    // MARK: - Unit

    func testStreamRemovesContentLength() {
        let response = Response(stream: .init { _ in })

        XCTAssertTrue(response.isStreaming)
        XCTAssertNil(response.headers.get(.contentLength))
    }

    func testAssigningStreamRemovesContentLength() {
        var response = Response("static")
        XCTAssertEqual(response.headers.get(.contentLength), "6")

        response.stream = .init { _ in }

        XCTAssertNil(response.headers.get(.contentLength))
    }

    // MARK: - Integration

    func testChunksAreConcatenatedAndChunkedEncodingIsUsed() throws {
        let response = Response(
            stream: .init { writer in
                try await writer.write("data: 1\n\n")
                try await Task.sleep(for: .milliseconds(20))
                try await writer.write("data: 2\n\n")
                try await writer.write(Body(string: "data: 3\n\n"))
            },
            headers: .init((.contentType, "text/event-stream"))
        )

        let (head, body) = try execute(response: response)

        XCTAssertEqual(head.status, .ok)
        XCTAssertEqual(head.headers.first(name: "content-type"), "text/event-stream")
        XCTAssertNil(head.headers.first(name: "content-length"))
        XCTAssertEqual(head.headers.first(name: "transfer-encoding"), "chunked")
        XCTAssertEqual(body, "data: 1\n\ndata: 2\n\ndata: 3\n\n")
    }

    func testProducerErrorEndsResponseCleanly() throws {
        struct Failure: Error {}
        let response = Response(stream: .init { writer in
            try await writer.write("partial")
            throw Failure()
        })

        let (_, body) = try execute(response: response)

        XCTAssertEqual(body, "partial")
    }

    func testHEADDropsStream() throws {
        let response = Response(stream: .init { writer in
            try await writer.write("should not be sent")
        })

        let (head, body) = try execute(response: response, method: .HEAD)

        XCTAssertEqual(head.status, .ok)
        XCTAssertEqual(body, "")
    }

    func testProducerIsCancelledWhenClientDisconnects() {
        let cancelled = expectation(description: "producer cancelled")
        let response = Response(stream: .init { writer in
            try await writer.write("hello")

            do {
                // Stand-in for "wait for the next event": only cancellation ends it.
                try await Task.sleep(for: .seconds(30))
            } catch is CancellationError {
                cancelled.fulfill()
            }
        })

        server.onReceive = { _ in response }
        startServer()

        let request = try! HTTPClient.Request(url: url, method: .GET)
        // Aborts the request once the stream is flowing, as a closing browser tab would.
        _ = client.execute(request: request, delegate: CancelOnFirstChunkDelegate())

        wait(for: [cancelled], timeout: 5)
    }
}

// MARK: - Helpers

extension ResponseStreamTests {
    var url: String { URI(server.configuration.socketAddress)!.string! }

    func startServer() {
        let started = expectation(description: "server started")
        server.onStart = { _ in started.fulfill() }

        let server = server!
        Thread { try? server.start() }.start()

        wait(for: [started], timeout: 5)
    }

    func execute(
        response: Response,
        method: HTTPMethod = .GET
    ) throws -> (HTTPResponseHead, String) {
        server.onReceive = { _ in response }
        startServer()

        let request = try HTTPClient.Request(url: url, method: method)
        let httpResponse = try client.execute(request: request).wait()
        let head = HTTPResponseHead(
            version: httpResponse.version,
            status: httpResponse.status,
            headers: httpResponse.headers
        )

        return (head, httpResponse.body.map { String(buffer: $0) } ?? "")
    }
}

/// Cancels the request as soon as the first body chunk arrives.
private final class CancelOnFirstChunkDelegate: HTTPClientResponseDelegate, @unchecked Sendable {
    typealias Response = Void

    private let didCancel = Box(false)

    func didReceiveBodyPart(task: HTTPClient.Task<Void>, _ buffer: ByteBuffer) -> EventLoopFuture<Void> {
        if !didCancel.value {
            didCancel.value = true
            task.cancel()
        }

        return task.eventLoop.makeSucceededFuture(())
    }

    func didFinishRequest(task: HTTPClient.Task<Void>) throws {}
}
