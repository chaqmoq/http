import XCTest
@testable import HTTP

final class RequestTests: XCTestCase {
    static var allTests = [
        ("testDefaultInit", testDefaultInit),
        ("testCustomInit", testCustomInit),
        ("testUpdate", testUpdate),
        ("testMethods", testMethods),
        ("testDescription", testDescription)
    ]

    func testDefaultInit() {
        // Arrange
        let request = Request()

        // Assert
        XCTAssertEqual(request.method, .GET)
        XCTAssertEqual(request.uri, "/")
        XCTAssertEqual(request.version.major, 1)
        XCTAssertEqual(request.version.minor, 1)
        XCTAssertTrue(request.headers.isEmpty)
        XCTAssertTrue(request.body.isEmpty)
        XCTAssertNil(request.pathParameters)
        XCTAssertNil(request.queryParameters)
        XCTAssertNil(request.bodyParameters)
        XCTAssertNil(request.files)
    }

    func testCustomInit() {
        // Arrange
        let method: Request.Method = .POST
        let uri = "/posts"
        let version: ProtocolVersion = .init(major: 2, minor: 0)
        let headers: ParameterBag<Header, String> = [.contentType: "application/json"]
        let body: Body = .init(string: "{\"title\": \"New post\"}")
        let request = Request(method: method, uri: uri, version: version, headers: headers, body: body)

        // Assert
        XCTAssertEqual(request.method, method)
        XCTAssertEqual(request.uri, uri)
        XCTAssertEqual(request.version.major, version.major)
        XCTAssertEqual(request.version.minor, version.minor)
        XCTAssertEqual(request.headers, headers)
        XCTAssertFalse(request.body.isEmpty)
        XCTAssertNil(request.pathParameters)
        XCTAssertNil(request.queryParameters)
        XCTAssertEqual(request.bodyParameters?.count, 1)
        XCTAssertEqual(request.bodyParameters?["title"] as? String, "New post")
        XCTAssertNil(request.files)
    }

    func testUpdate() {
        // Arrange
        let method: Request.Method = .POST
        let uri = "/posts"
        let version: ProtocolVersion = .init(major: 2, minor: 0)
        let headers: ParameterBag<Header, String> = [.contentType: "application/json"]
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
        XCTAssertEqual(request.headers, headers)
        XCTAssertFalse(request.body.isEmpty)
        XCTAssertNil(request.pathParameters)
        XCTAssertNil(request.queryParameters)
        XCTAssertEqual(request.bodyParameters?.count, 1)
        XCTAssertEqual(request.bodyParameters?["title"] as? String, "New post")
        XCTAssertNil(request.files)
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

        for (header, value) in request.headers {
            string.append("\(header.rawValue): \(value)\n")
        }

        string.append("\n\(request.body)")
        string = """
        \(request.method) \(request.uri) \(request.version)\n\(string)
        """

        // Assert
        XCTAssertEqual("\(request)", string)
    }
}
