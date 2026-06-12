import AsyncHTTPClient
@testable import HTTP
import NIO
import NIOHTTP1
import XCTest

private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

/// Integration tests that send requests with non-empty bodies, ensuring RequestDecoder's
/// `.body(chunk)` state-machine branch is exercised.
final class RequestBodyDecoderTests: XCTestCase, @unchecked Sendable {
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
        let receivedBody = Box<String?>(nil)

        execute(method: .POST, body: jsonString, contentType: "application/json") { request in
            receivedBody.value = request.body.string
        } responseHandler: { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(receivedBody.value, jsonString)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPOSTWithFormBodyIsDecoded() {
        let formBody = "username=sukhrob&password=secret"
        let receivedParameters = Box<[String: Any]>([:])

        execute(method: .POST, body: formBody, contentType: "application/x-www-form-urlencoded") { request in
            receivedParameters.value["username"] = request.parameters["username"]?.value
            receivedParameters.value["password"] = request.parameters["password"]?.value
        } responseHandler: { result in
            switch result {
            case .success:
                XCTAssertEqual(receivedParameters.value["username"] as? String, "sukhrob")
                XCTAssertEqual(receivedParameters.value["password"] as? String, "secret")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPUTWithLargeBodyIsDecoded() {
        // A larger body forces NIO to split it into multiple chunks,
        // exercising the append path inside the .body(chunk) case.
        let largeBody = String(repeating: "A", count: 4096)
        let receivedCount = Box(0)

        execute(method: .PUT, body: largeBody, contentType: "text/plain") { request in
            receivedCount.value = request.body.count
        } responseHandler: { result in
            switch result {
            case .success:
                XCTAssertEqual(receivedCount.value, 4096)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPATCHWithBodyReturnsCorrectResponse() {
        let body = "patch-payload"
        let receivedBody = Box<String?>(nil)

        execute(method: .PATCH, body: body, contentType: "text/plain") { request in
            receivedBody.value = request.body.string
        } responseHandler: { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(receivedBody.value, body)
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
        responseHandler: @escaping @Sendable (Result<Response, Error>) -> Void
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
