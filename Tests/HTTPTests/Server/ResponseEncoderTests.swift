import AsyncHTTPClient
@testable import HTTP
import NIO
import XCTest

/// Tests that drive ResponseEncoder directly via the live server.
final class ResponseEncoderTests: XCTestCase {
    var client: HTTPClient!
    var server: Server!

    override func setUp() {
        super.setUp()
        client = HTTPClient(eventLoopGroupProvider: .singleton)
        server = Server(configuration: .init(numberOfThreads: 1))
    }

    // MARK: - Empty body (ResponseEncoder skips the body write)

    func testEmptyBodyResponse() {
        execute(response: Response()) { result in
            switch result {
            case .success(let response):
                XCTAssertTrue(response.body.isEmpty)
                XCTAssertEqual(response.status, .ok)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Non-empty body (ResponseEncoder writes the body buffer)

    func testNonEmptyBodyResponse() {
        let body = Body(string: "Hello, ResponseEncoder!")
        execute(response: Response(body)) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.body.string, "Hello, ResponseEncoder!")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Status codes are encoded correctly

    func testCreatedStatusCode() {
        execute(response: Response(status: .created)) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.status, .created)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testNotFoundStatusCode() {
        execute(response: Response(status: .notFound)) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.status, .notFound)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - Response headers are forwarded

    func testCustomHeadersAreForwarded() {
        var response = Response("body")
        response.headers.set(.init(name: .contentType, value: "application/json"))

        execute(response: response) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.headers.get(.contentType), "application/json")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
}

extension ResponseEncoderTests {
    func execute(
        response: Response,
        responseHandler: @escaping (Result<Response, Error>) -> Void
    ) {
        let uri = URI(server.configuration.socketAddress)!

        server.onStart = { [weak self] _ in
            guard let self else { return }

            let request = try! HTTPClient.Request(url: uri.string!, method: .GET)

            client.execute(request: request).whenComplete { [weak self] result in
                switch result {
                case .failure(let error):
                    responseHandler(.failure(error))
                case .success(let httpResponse):
                    let status = Response.Status(rawValue: Int(httpResponse.status.code)) ?? .ok
                    var headers = Headers()

                    for header in httpResponse.headers {
                        headers.set(.init(name: header.name, value: header.value))
                    }

                    let body: Body
                    if let buf = httpResponse.body,
                       let bytes = buf.getBytes(at: 0, length: buf.readableBytes) {
                        body = Body(bytes: bytes)
                    } else {
                        body = Body()
                    }

                    responseHandler(.success(Response(body, status: status, headers: headers)))
                }

                DispatchQueue.global().asyncAfter(deadline: .now()) { [weak self] in
                    try! self?.client.syncShutdown()
                    try! self?.server.stop()
                }
            }
        }

        server.onReceive = { _ in response }
        try! server.start()
    }
}
