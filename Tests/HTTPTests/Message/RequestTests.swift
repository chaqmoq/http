import XCTest
@testable import HTTP

final class RequestTests: XCTestCase {
    func testDefaultInit() {
        // Arrange
        let request = Request()

        // Assert
        XCTAssertEqual(request.method, .GET)
        XCTAssertEqual(request.uri, .default)
        XCTAssertEqual(request.version, .init(major: 1, minor: 1))
        XCTAssertEqual(request.headers.value(for: Header.contentLength.rawValue), String(request.body.count))
        XCTAssertTrue(request.body.isEmpty)
    }

    func testCustomInit() {
        // Arrange
        let method: Request.Method = .POST
        let uri = URI(string: "/posts")!
        let version: Version = .init(major: 2, minor: 0)
        let headers: HeaderBag = [Header.contentType.rawValue: "application/json"]
        let body: Body = .init(string: "{\"title\": \"New post\"}")
        let request = Request(method: method, uri: uri, version: version, headers: headers, body: body)

        // Assert
        XCTAssertEqual(request.method, method)
        XCTAssertEqual(request.uri, uri)
        XCTAssertEqual(request.version, version)
        XCTAssertEqual(request.headers.value(for: Header.contentLength.rawValue), String(request.body.count))
        XCTAssertEqual(request.headers.value(for: Header.contentType.rawValue), "application/json")
        XCTAssertFalse(request.body.isEmpty)
    }

    func testUpdate() {
        // Arrange
        let method: Request.Method = .POST
        let uri = URI(string: "/posts")!
        let version: Version = .init(major: 2, minor: 0)
        let headers: HeaderBag = [Header.contentType.rawValue: "application/json"]
        let body: Body = .init(string: "{\"title\": \"New post\"}")
        var request = Request()

        // Act
        request.method = method
        request.uri = uri
        request.version = version
        request.headers = headers
        request.body = body

        // Assert
        XCTAssertEqual(request.method, method)
        XCTAssertEqual(request.uri, uri)
        XCTAssertEqual(request.version, version)
        XCTAssertEqual(request.headers.value(for: Header.contentLength.rawValue), String(request.body.count))
        XCTAssertEqual(request.headers.value(for: Header.contentType.rawValue), "application/json")
        XCTAssertFalse(request.body.isEmpty)
    }

    func testMethods() {
        // Assert
        for method in Request.Method.allCases {
            let rawValue = method.rawValue

            switch method {
            case .DELETE:
                XCTAssertEqual(rawValue, "DELETE")
            case .GET:
                XCTAssertEqual(rawValue, "GET")
            case .HEAD:
                XCTAssertEqual(rawValue, "HEAD")
            case .OPTIONS:
                XCTAssertEqual(rawValue, "OPTIONS")
            case .PATCH:
                XCTAssertEqual(rawValue, "PATCH")
            case .POST:
                XCTAssertEqual(rawValue, "POST")
            case .PUT:
                XCTAssertEqual(rawValue, "PUT")
            }
        }
    }

    func testDescription() {
        // Arrange
        let request = Request()
        var string = ""

        for (name, value) in request.headers {
            string.append("\(name): \(value)\n")
        }

        string.append("\n\(request.body)")
        string = """
        \(request.method) \(request.uri) \(request.version)\n\(string)
        """

        // Assert
        XCTAssertEqual("\(request)", string)
    }
}
