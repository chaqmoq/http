@testable import HTTP
import NIO
import XCTest

final class RequestTests: XCTestCase {
    let eventLoop = EmbeddedEventLoop()

    func testDefaultInit() {
        // Act
        let request = Request(eventLoop: eventLoop)

        // Assert
        XCTAssertEqual(request.method, .GET)
        XCTAssertEqual(request.uri, .default)
        XCTAssertEqual(request.version, .init(major: 1, minor: 1))
        XCTAssertEqual(request.headers.get(.contentLength), String(request.body.count))
        XCTAssertTrue(request.attributes.isEmpty)
        XCTAssertTrue(request.cookies.isEmpty)
        XCTAssertTrue(request.files.isEmpty)
        XCTAssertTrue(request.parameters.isEmpty)
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

        // Act
        let request = Request(
            eventLoop: eventLoop,
            method: method,
            uri: uri,
            version: version,
            headers: headers,
            body: body
        )

        // Assert
        XCTAssertEqual(request.method, method)
        XCTAssertEqual(request.uri, uri)
        XCTAssertEqual(request.version, version)
        XCTAssertEqual(request.headers.get(.contentLength), String(request.body.count))
        XCTAssertEqual(request.headers.get(.contentType), "application/json")
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
        var request = Request(
            eventLoop: eventLoop,
            headers: .init([.cookie: "sessionId=abcd; userId1=1; username1"])
        )

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
        XCTAssertEqual(request.headers.get(.contentLength), String(request.body.count))
        XCTAssertEqual(request.headers.get(.contentType), "application/json")
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
        let request = Request(eventLoop: eventLoop)

        // Act
        var description = ""
        for header in request.headers { description.append("\(header.name): \(header.value)\n") }
        description.append("\n\(request.body)")
        description = """
        \(request.method) \(request.uri) \(request.version)\n\(description)
        """

        // Assert
        XCTAssertEqual("\(request)", description)
    }

    func testHasCookie() {
        // Arrange
        let request = Request(eventLoop: eventLoop, headers: .init([.cookie: "sessionId=abcd; userId=1"]))

        // Assert
        XCTAssertEqual(request.cookies.count, 2)
        XCTAssertTrue(request.hasCookie(named: "sessionId"))
        XCTAssertTrue(request.hasCookie(named: "userId"))
        XCTAssertFalse(request.hasCookie(named: "email"))
        XCTAssertFalse(request.hasCookie(named: "username"))
    }

    func testSetCookie() {
        // Arrange
        var request = Request(eventLoop: eventLoop)

        // Act
        request.setCookie(Cookie(name: "sessionId", value: "abcd"))

        // Assert
        XCTAssertEqual(request.headers.get(.cookie), "sessionId=abcd")
        XCTAssertEqual(request.cookies.count, 1)
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "sessionId" && $0.value == "abcd" }))

        // Act
        request.setCookie(Cookie(name: "sessionId", value: "efgh"))

        // Assert
        XCTAssertEqual(request.headers.get(.cookie), "sessionId=efgh")
        XCTAssertEqual(request.cookies.count, 1)
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "sessionId" && $0.value == "efgh" }))

        // Act
        request.setCookie(Cookie(name: "userId", value: "1"))

        // Assert
        XCTAssertEqual(request.headers.get(.cookie), "sessionId=efgh; userId=1")
        XCTAssertEqual(request.cookies.count, 2)
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "sessionId" && $0.value == "efgh" }))
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "userId" && $0.value == "1" }))
    }

    func testClearCookie() {
        // Arrange
        var request = Request(eventLoop: eventLoop)

        // Assert
        XCTAssertNil(request.headers.get(.cookie))
        XCTAssertTrue(request.cookies.isEmpty)

        // Act
        request.clearCookie(named: "sessionId")

        // Assert
        XCTAssertNil(request.headers.get(.cookie))
        XCTAssertTrue(request.cookies.isEmpty)

        // Act
        request.headers = .init([
            .cookie: "sessionId=abcd; userId=1; email=sukhrob@chaqmoq.dev; username=sukhrob"
        ])

        // Assert
        XCTAssertEqual(
            request.headers.get(.cookie),
            "sessionId=abcd; userId=1; email=sukhrob@chaqmoq.dev; username=sukhrob"
        )
        XCTAssertEqual(request.cookies.count, 4)
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "sessionId" && $0.value == "abcd" }))
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "userId" && $0.value == "1" }))
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "email" && $0.value == "sukhrob@chaqmoq.dev" }))
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "username" && $0.value == "sukhrob" }))

        // Act
        request.clearCookie(named: "sessionId")

        // Assert
        XCTAssertEqual(request.headers.get(.cookie), "userId=1; email=sukhrob@chaqmoq.dev; username=sukhrob")
        XCTAssertEqual(request.cookies.count, 3)
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "userId" && $0.value == "1" }))
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "email" && $0.value == "sukhrob@chaqmoq.dev" }))
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "username" && $0.value == "sukhrob" }))

        // Act
        request.clearCookie(named: "email")

        // Assert
        XCTAssertEqual(request.headers.get(.cookie), "userId=1; username=sukhrob")
        XCTAssertEqual(request.cookies.count, 2)
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "userId" && $0.value == "1" }))
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "username" && $0.value == "sukhrob" }))

        // Act
        request.clearCookie(named: "username")

        // Assert
        XCTAssertEqual(request.headers.get(.cookie), "userId=1")
        XCTAssertEqual(request.cookies.count, 1)
        XCTAssertTrue(request.cookies.contains(where: { $0.name == "userId" && $0.value == "1" }))

        // Act
        request.clearCookie(named: "userId")

        // Assert
        XCTAssertNil(request.headers.get(.cookie))
        XCTAssertTrue(request.cookies.isEmpty)
    }

    func testClearCookies() {
        // Arrange
        let headers: Headers = .init([.cookie: "sessionId=abcd; userId=1"])
        var request = Request(eventLoop: eventLoop, headers: headers)

        // Act
        request.clearCookies()

        // Assert
        XCTAssertNil(request.headers.get(.cookie))
        XCTAssertTrue(request.cookies.isEmpty)
    }
}
