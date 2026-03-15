import AsyncHTTPClient
@testable import HTTP
import NIO
import NIOHTTP1
import XCTest

/// Integration tests that send requests with non-empty bodies, ensuring RequestDecoder's
/// `.body(chunk)` state-machine branch is exercised.
final class RequestBodyDecoderTests: XCTestCase {
    var client: HTTPClient!
    var server: Server!

    override func setUp() {
        super.setUp()
        client = HTTPClient(eventLoopGroupProvider: .singleton)
        server = Server(configuration: .init(port: 8081, numberOfThreads: 1))
    }

    // MARK: - POST with JSON body hits RequestDecoder .body(chunk) path

    func testPOSTWithJSONBodyIsDecoded() {
        let jsonString = #"{"name":"swift","version":6}"#
        var receivedBody: String?

        execute(method: .POST, body: jsonString, contentType: "application/json") { request in
            receivedBody = request.body.string
        } responseHandler: { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(receivedBody, jsonString)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPOSTWithFormBodyIsDecoded() {
        let formBody = "username=sukhrob&password=secret"
        var receivedParameters: [String: Any] = [:]

        execute(method: .POST, body: formBody, contentType: "application/x-www-form-urlencoded") { request in
            receivedParameters["username"] = request.parameters["username"]?.value
            receivedParameters["password"] = request.parameters["password"]?.value
        } responseHandler: { result in
            switch result {
            case .success:
                XCTAssertEqual(receivedParameters["username"] as? String, "sukhrob")
                XCTAssertEqual(receivedParameters["password"] as? String, "secret")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPUTWithLargeBodyIsDecoded() {
        // A larger body forces NIO to split it into multiple chunks,
        // exercising the append path inside the .body(chunk) case.
        let largeBody = String(repeating: "A", count: 4096)
        var receivedCount = 0

        execute(method: .PUT, body: largeBody, contentType: "text/plain") { request in
            receivedCount = request.body.count
        } responseHandler: { result in
            switch result {
            case .success:
                XCTAssertEqual(receivedCount, 4096)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPATCHWithBodyReturnsCorrectResponse() {
        let body = "patch-payload"
        var receivedBody: String?

        execute(method: .PATCH, body: body, contentType: "text/plain") { request in
            receivedBody = request.body.string
        } responseHandler: { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(receivedBody, body)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
}

// MARK: - Helper

extension RequestBodyDecoderTests {
    func execute(
        method: Request.Method,
        body: String,
        contentType: String,
        requestHandler: @escaping (Request) -> Void,
        responseHandler: @escaping (Result<Response, Error>) -> Void
    ) {
        let uri = URI(server.configuration.socketAddress)!

        server.onStart = { [weak self] _ in
            guard let self else { return }

            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: contentType)

            var buffer = ByteBufferAllocator().buffer(capacity: body.utf8.count)
            buffer.writeString(body)

            let clientRequest = try! HTTPClient.Request(
                url: uri.string!,
                method: HTTPMethod(rawValue: method.rawValue),
                headers: headers,
                body: .byteBuffer(buffer)
            )

            client.execute(request: clientRequest).whenComplete { [weak self] result in
                switch result {
                case .failure(let error):
                    responseHandler(.failure(error))
                case .success(let httpResponse):
                    let status = Response.Status(rawValue: Int(httpResponse.status.code)) ?? .ok
                    responseHandler(.success(Response(status: status)))
                }

                DispatchQueue.global().asyncAfter(deadline: .now()) { [weak self] in
                    try! self?.client.syncShutdown()
                    try! self?.server.stop()
                }
            }
        }

        server.onReceive = { request in
            requestHandler(request)

            return Response()
        }

        try! server.start()
    }
}
