import XCTest
@testable import HTTP

final class PlainTextTests: ClientServerTests {
    func testGet() {
        let request = Request(method: .GET, uri: URI(string: server.configuration.socketAddress)!)
        let response = Response(body: .init(string: "Hello World"))
        execute(request, expecting: response, requestHandler: { actualRequest in
            // TODO: add assertions
        }) { result in
            switch result {
            case .failure(let error):
                XCTFail(error.localizedDescription)
            case .success(let actualResponse):
                XCTAssertEqual(actualResponse, response)
            }
        }
    }

    func testHead() {
        let request = Request(method: .HEAD, uri: URI(string: server.configuration.socketAddress)!)
        let response = Response()
        execute(request, expecting: response, requestHandler: { actualRequest in
            // TODO: add assertions
        }) { result in
            switch result {
            case .failure(let error):
                XCTFail(error.localizedDescription)
            case .success(let actualResponse):
                XCTAssertEqual(actualResponse, response)
            }
        }
    }
}