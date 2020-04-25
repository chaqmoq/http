import NIO
import NIOHTTP1
import AsyncHTTPClient
import XCTest
@testable import HTTP

class ClientServerTests: XCTestCase {
    var client: HTTPClient!
    var server: Server!

    override func setUp() {
        super.setUp()

        client = HTTPClient(eventLoopGroupProvider: .createNew)
        server = Server(configuration: .init(numberOfThreads: 1))
    }

    func execute(
        _ request: Request,
        expecting response: Response,
        resultHandler: @escaping (Result<Response, Error>) -> Void
    ) {
        server.onStart = { [weak self] _ in
            guard let weakSelf = self else { fatalError() }
            let url = weakSelf.server.configuration.socketAddress
            let method = HTTPMethod(rawValue: request.method.rawValue)
            var headers = HTTPHeaders()

            for (name, value) in response.headers {
                headers.add(name: name, value: value)
            }

            var buffer = ByteBufferAllocator().buffer(capacity: response.body.count)
            buffer.writeBytes(response.body.bytes)
            let body: HTTPClient.Body = .byteBuffer(buffer)

            let request = try! HTTPClient.Request(url: url, method: method, headers: headers, body: body)
            weakSelf.client.execute(request: request).whenComplete { result in
                switch result {
                case .failure(let error):
                    resultHandler(.failure(error))
                case .success(let response):
                    let status = Response.Status(rawValue: Int(response.status.code))!
                    var headers = ParameterBag<String, String>()

                    for header in response.headers {
                        headers[header.name] = header.value
                    }

                    let bytes = response.body!.getBytes(at: 0, length: response.body!.readableBytes)!
                    let response = Response(status: status, headers: headers, body: Body(bytes: bytes))
                    resultHandler(.success(response))
                }

                DispatchQueue.global().asyncAfter(deadline: .now()) {
                    try! weakSelf.client.syncShutdown()
                    try! weakSelf.server.stop()
                }
            }
        }
        server.onReceive = { request, _ in
            return response
        }
        try! server.start()
    }
}
