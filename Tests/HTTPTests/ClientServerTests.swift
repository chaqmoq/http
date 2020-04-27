import NIO
import NIOHTTP1
import AsyncHTTPClient
import XCTest
@testable import HTTP

class ClientServerTests: XCTestCase {
    var client: HTTPClient!
    var server: Server!
    var request: Request!

    override func setUp() {
        super.setUp()

        client = HTTPClient(eventLoopGroupProvider: .createNew)
        server = Server(configuration: .init(numberOfThreads: 1))
    }

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

            for (name, value) in response.headers {
                headers.add(name: name, value: value)
            }

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
                    var headers = ParameterBag<String, String>()

                    for header in response.headers {
                        headers[header.name] = header.value
                    }

                    let actualResponse: Response

                    if let body = response.body, let bytes = body.getBytes(at: 0, length: body.readableBytes) {
                        actualResponse = Response(status: status, headers: headers, body: Body(bytes: bytes))
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
