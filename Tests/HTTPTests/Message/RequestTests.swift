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
        XCTAssertEqual(request.headers.value(for: .contentLength), String(request.body.count))
        XCTAssertTrue(request.cookies.isEmpty)
        XCTAssertTrue(request.body.isEmpty)
    }

    func testCustomInit() {
        // Arrange
        let method: Request.Method = .POST
        let uri = URI(string: "/posts")!
        let version: Version = .init(major: 2, minor: 0)
        let headers: Headers = .init(
            (.contentType, "application/json"),
            (.cookie, "sessionId=abcd; userId=1; username"),
            (.cookie, "sessionId=efgh; userId=2; username")
        )
        let body: Body = .init(string: "{\"title\": \"New post\"}")
        let request = Request(method: method, uri: uri, version: version, headers: headers, body: body)

        // Assert
        XCTAssertEqual(request.method, method)
        XCTAssertEqual(request.uri, uri)
        XCTAssertEqual(request.version, version)
        XCTAssertEqual(request.headers.value(for: .contentLength), String(request.body.count))
        XCTAssertEqual(request.headers.value(for: .contentType), "application/json")
        XCTAssertEqual(request.cookies.count, 2)
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "sessionId" && $0.value == "efgh" }))
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "userId" && $0.value == "2" }))
        XCTAssertFalse(request.body.isEmpty)
    }

    func testUpdate() {
        // Arrange
        let method: Request.Method = .POST
        let uri = URI(string: "/posts")!
        let version: Version = .init(major: 2, minor: 0)
        let headers: Headers = .init([
            .contentType: "application/json",
            .cookie: "sessionId=efgh; userId2=2; username2"
        ])
        let body: Body = .init(string: "{\"title\": \"New post\"}")
        var request = Request(headers: .init([.cookie: "sessionId=abcd; userId1=1; username1"]))

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
        XCTAssertEqual(request.headers.value(for: .contentLength), String(request.body.count))
        XCTAssertEqual(request.headers.value(for: .contentType), "application/json")
        XCTAssertEqual(request.cookies.count, 2)
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "sessionId" && $0.value == "efgh" }))
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "userId2" && $0.value == "2" }))
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

        // Act
        var description = ""
        for (name, value) in request.headers { description.append("\(name): \(value)\n") }
        description.append("\n\(request.body)")
        description = """
        \(request.method) \(request.uri) \(request.version)\n\(description)
        """

        // Assert
        XCTAssertEqual("\(request)", description)
    }

    func testSetCookie() {
        // Arrange
        var request = Request()

        // Act
        request.setCookie(Cookie(name: "sessionId", value: "abcd"))

        // Assert
        XCTAssertEqual(request.headers.value(for: .cookie), "sessionId=abcd")
        XCTAssertEqual(request.cookies.count, 1)
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "sessionId" && $0.value == "abcd" }))

        // Act
        request.setCookie(Cookie(name: "sessionId", value: "efgh"))

        // Assert
        XCTAssertEqual(request.headers.value(for: .cookie), "sessionId=efgh")
        XCTAssertEqual(request.cookies.count, 1)
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "sessionId" && $0.value == "efgh" }))

        // Act
        request.setCookie(Cookie(name: "userId", value: "1"))

        // Assert
        XCTAssertEqual(request.headers.value(for: .cookie), "sessionId=efgh; userId=1")
        XCTAssertEqual(request.cookies.count, 2)
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "sessionId" && $0.value == "efgh" }))
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "userId" && $0.value == "1" }))
    }

    func testClearCookie() {
        // Arrange
        let headers: Headers = .init([
            .cookie: "sessionId=abcd; userId=1; email=sukhrob@chaqmoq.dev; username=sukhrob"
        ])
        var request = Request(headers: headers)

        // Act
        request.clearCookie(named: "sessionId")

        // Assert
        XCTAssertEqual(request.headers.value(for: .cookie), "userId=1; email=sukhrob@chaqmoq.dev; username=sukhrob")
        XCTAssertEqual(request.cookies.count, 3)
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "userId" && $0.value == "1" }))
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "email" && $0.value == "sukhrob@chaqmoq.dev" }))
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "username" && $0.value == "sukhrob" }))

        // Act
        request.clearCookie(named: "email")

        // Assert
        XCTAssertEqual(request.headers.value(for: .cookie), "userId=1; username=sukhrob")
        XCTAssertEqual(request.cookies.count, 2)
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "userId" && $0.value == "1" }))
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "username" && $0.value == "sukhrob" }))

        // Act
        request.clearCookie(named: "username")

        // Assert
        XCTAssertEqual(request.headers.value(for: .cookie), "userId=1")
        XCTAssertEqual(request.cookies.count, 1)
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "userId" && $0.value == "1" }))

        // Act
        request.clearCookie(named: "userId")

        // Assert
        XCTAssertNil(request.headers.value(for: .cookie))
        XCTAssertTrue(request.cookies.isEmpty)
    }
}
