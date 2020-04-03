import XCTest
@testable import HTTP

final class RequestTests: XCTestCase {
    static var allTests = [
        ("testInitWithDefaultValues", testInitWithDefaultValues),
        ("testInitWithCustomValues", testInitWithCustomValues),
        ("testDescription", testDescription)
    ]

    func testInitWithDefaultValues() {
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

    func testInitWithCustomValues() {
        // Arrange
        let method: Request.Method = .POST
        let uri = "/posts"
        let version: ProtocolVersion = .init(major: 2, minor: 0)
        let headers: ParameterBag<Header, String> = [.contentType: "application/json"]
        let body: Body = .init(string: "{\"title\": \"New post\"}")
        let request = Request(
            method: .POST,
            uri: "/posts",
            version: version,
            headers: headers,
            body: body
        )

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

    func testDescription() {
        // Arrange
        let request = Request()

        // Act
        var string = ""

        for (header, value) in request.headers {
            string.append("\(header.rawValue): \(value)\n")
        }

        string.append("\n\(request.body)")
        string = """
        \(request.method) \(request.uri) HTTP/\(request.version.major).\(request.version.minor)\n\(string)
        """

        // Assert
        XCTAssertEqual("\(request)", string)
    }
}