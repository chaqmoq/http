import AsyncHTTPClient
@testable import HTTP
import NIO
import NIOHTTP1
import XCTest

class ClientServerTests: XCTestCase {
    var client: HTTPClient!
    var server: Server!
    let eventLoop = EmbeddedEventLoop()

    override func setUp() {
        super.setUp()

        client = HTTPClient(eventLoopGroupProvider: .singleton)
        server = Server(
            configuration: .init(
                serverName: "Apache/2.4.1 (Unix)",
                numberOfThreads: 1
            )
        )
        server.middleware = [
            CORSMiddleware(),
            HTTPMethodOverrideMiddleware()
        ]
    }

    func testRequestResponse() {
        let request = Request(
            eventLoop: eventLoop,
            method: .POST,
            uri: .init(server.configuration.socketAddress)!
        )
        let response = Response()
        execute(request, expecting: response) { actualRequest in
            XCTAssertEqual(request.method, actualRequest.method)
        } responseHandler: { result in
            switch result {
            case .success(let actualResponse):
                XCTAssertEqual(response.status, actualResponse.status)
            case .failure(let error):
                XCTAssertThrowsError(error)
            }
        }
    }
}

extension ClientServerTests {
    func execute(
        _ request: Request,
        expecting response: Response,
        requestHandler: @escaping (Request) -> Void,
        responseHandler: @escaping (Result<Response, Error>) -> Void
    ) {
        server.onStart = { [weak self] _ in
            guard let self else { return }

            let url = request.uri.string!
            let method = HTTPMethod(rawValue: request.method.rawValue)
            var headers = HTTPHeaders()
            for header in response.headers { headers.add(name: header.name, value: header.value) }

            var buffer = ByteBufferAllocator().buffer(capacity: request.body.count)
            buffer.writeBytes(request.body.bytes)
            let body: HTTPClient.Body = .byteBuffer(buffer)

            var request = try! HTTPClient.Request(url: url, method: method, body: body)
            for header in request.headers { request.headers.add(name: header.name, value: header.value) }
            client.execute(request: request).whenComplete { result in
                switch result {
                case let .failure(error):
                    responseHandler(.failure(error))
                case let .success(response):
                    let status = Response.Status(rawValue: Int(response.status.code))!
                    var headers = Headers()

                    for header in response.headers {
                        headers.set(.init(name: header.name, value: header.value))
                    }

                    let actualResponse: Response

                    if let body = response.body, let bytes = body.getBytes(at: 0, length: body.readableBytes) {
                        actualResponse = Response(.init(bytes: bytes), status: status, headers: headers)
                    } else {
                        actualResponse = Response(status: status, headers: headers)
                    }

                    responseHandler(.success(actualResponse))
                }

                DispatchQueue.global().asyncAfter(deadline: .now()) { [weak self] in
                    try! self?.client.syncShutdown()
                    try! self?.server.stop()
                }
            }
        }
        server.onReceive = { request in
            requestHandler(request)
            return response
        }
        try! server.start()
    }
}
