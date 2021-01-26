import AsyncHTTPClient
@testable import HTTP
import NIO
import NIOHTTP1
import XCTest

class ClientServerTests: XCTestCase {
    var client: HTTPClient!
    var server: Server!
    var request: Request!

    override func setUp() {
        super.setUp()

        client = HTTPClient(eventLoopGroupProvider: .createNew)
        server = Server(
            configuration: .init(
                serverName: "Apache/2.4.1 (Unix)",
                numberOfThreads: 1,
                requestDecompression: .init(isEnabled: true),
                responseCompression: .init(isEnabled: true)
            )
        )
    }
}

extension ClientServerTests {
    func execute(
        _ request: Request,
        expecting response: Response,
        requestHandler: @escaping (Request) -> Void,
        responseHandler: @escaping (Result<Response, Error>) -> Void
    ) {
        self.request = request
        server.onStart = { [weak self] _ in
            guard let weakSelf = self else { fatalError() }
            let url = weakSelf.request.uri.string!
            let method = HTTPMethod(rawValue: weakSelf.request.method.rawValue)
            var headers = HTTPHeaders()
            for header in response.headers { headers.add(name: header.name, value: header.value) }

            var buffer = ByteBufferAllocator().buffer(capacity: request.body.count)
            buffer.writeBytes(request.body.bytes)
            let body: HTTPClient.Body = .byteBuffer(buffer)

            let request = try! HTTPClient.Request(url: url, method: method, headers: headers, body: body)
            weakSelf.client.execute(request: request).whenComplete { result in
                switch result {
                case .failure(let error):
                    responseHandler(.failure(error))
                case .success(let response):
                    let status = Response.Status(rawValue: Int(response.status.code))!
                    var headers = Headers()

                    for header in response.headers {
                        headers.set(header.value, for: header.name)
                    }

                    let actualResponse: Response

                    if let body = response.body, let bytes = body.getBytes(at: 0, length: body.readableBytes) {
                        actualResponse = Response(.init(bytes: bytes), status: status, headers: headers)
                    } else {
                        actualResponse = Response(status: status, headers: headers)
                    }

                    responseHandler(.success(actualResponse))
                }

                DispatchQueue.global().asyncAfter(deadline: .now()) {
                    try! weakSelf.client.syncShutdown()
                    try! weakSelf.server.stop()
                }
            }
        }
        server.onReceive = { request, _ in
            requestHandler(request)
            return response
        }
        try! server.start()
    }
}
