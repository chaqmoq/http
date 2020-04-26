import XCTest
@testable import HTTP

final class PlainTextTests: ClientServerTests {
    func testGet() {
        let request = Request(method: .GET)
        let response = Response(body: .init(string: "Hello World"))
        execute(request, expecting: response) { result in
            switch result {
            case .failure(let error):
                XCTFail(error.localizedDescription)
            case .success(let actualResponse):
                XCTAssertEqual(actualResponse, response)
            }
        }
    }
}
