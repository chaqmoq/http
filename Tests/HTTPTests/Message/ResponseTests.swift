@testable import HTTP
import XCTest

final class ResponseTests: XCTestCase {
    func testDefaultInit() {
        // Act
        let response = Response()

        // Assert
        XCTAssertEqual(response.version, .init(major: 1, minor: 1))
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(response.headers.value(for: .contentLength), String(response.body.count))
        XCTAssertTrue(response.cookies.isEmpty)
        XCTAssertTrue(response.body.isEmpty)
    }

    func testInitWithString() {
        // Arrange
        let string = "Hello World"

        // Act
        let response = Response(string)

        // Assert
        XCTAssertEqual(response.version, .init(major: 1, minor: 1))
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(response.headers.value(for: .contentLength), String(response.body.count))
        XCTAssertTrue(response.cookies.isEmpty)
        XCTAssertEqual(response.body.string, string)
    }

    func testInitWithData() {
        // Arrange
        let data = "Hello World".data(using: .utf8)!

        // Act
        let response = Response(data)

        // Assert
        XCTAssertEqual(response.version, .init(major: 1, minor: 1))
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(response.headers.value(for: .contentLength), String(response.body.count))
        XCTAssertTrue(response.cookies.isEmpty)
        XCTAssertEqual(response.body.data, data)
    }

    func testCustomInit() {
        // Arrange
        let status: Response.Status = .created
        let version: Version = .init(major: 2, minor: 0)
        let headers: Headers = .init(
            (.contentType, "application/json"),
            (.setCookie, "sessionId=abcd; Expires=Sat, 13 Jun 2020 19:15:12 GMT; Max-Age=86400; Domain=chaqmoq.dev;"),
            (.setCookie, "sessionId=abcd; Path=/blog; Secure; HttpOnly; SameSite=Lax")
        )
        let body: Body = .init(string: "{\"title\": \"New post\"}")

        // Act
        let response = Response(body, status: status, headers: headers, version: version)

        // Assert
        XCTAssertEqual(response.version, version)
        XCTAssertEqual(response.status, status)
        XCTAssertEqual(response.headers.value(for: .contentLength), String(response.body.count))
        XCTAssertEqual(response.headers.value(for: .contentType), "application/json")
        XCTAssertEqual(response.cookies.count, 1)
        XCTAssertTrue(response.cookies.contains(where: {
            $0.name == "sessionId" &&
            $0.value == "abcd" &&
            $0.expires == Date(rfc1123: "Sat, 13 Jun 2020 19:15:12 GMT") &&
            $0.maxAge == 86400 &&
            $0.domain == "chaqmoq.dev" &&
            $0.path == "/blog" &&
            $0.isSecure &&
            $0.isHTTPOnly &&
            $0.sameSite == .lax
        }))
        XCTAssertFalse(response.body.isEmpty)
    }

    func testUpdate() {
        // Arrange
        let status: Response.Status = .created
        let version: Version = .init(major: 2, minor: 0)
        let headers: Headers = .init(
            (.contentType, "application/json"),
            (.setCookie, """
            sessionId=efgh; Expires=Sun, 14 Jun 2020 20:21:45 GMT; Max-Age=96400; Domain=docs.chaqmoq.dev; \
            Path=/get-started; SameSite=Strict
            """),
            (.setCookie, "sessionId=efgh; SameSite=None")
        )
        let body: Body = .init(string: "{\"title\": \"New post\"}")
        var response = Response(headers: .init([
            .setCookie: """
            sessionId=abcd; Expires=Sat, 13 Jun 2020 19:15:12 GMT; Max-Age=86400; Domain=chaqmoq.dev; \
            Path=/blog; Secure; HttpOnly; SameSite=Lax
            """
        ]))

        // Act
        response.version = version
        response.status = status
        response.headers = headers
        response.body = body

        // Assert
        XCTAssertEqual(response.version, version)
        XCTAssertEqual(response.status, status)
        XCTAssertEqual(response.headers.value(for: .contentLength), String(response.body.count))
        XCTAssertEqual(response.headers.value(for: .contentType), "application/json")
        XCTAssertEqual(response.cookies.count, 1)
        XCTAssertTrue(response.cookies.contains(where: {
            $0.name == "sessionId" &&
            $0.value == "efgh" &&
            $0.expires == Date(rfc1123: "Sun, 14 Jun 2020 20:21:45 GMT") &&
            $0.maxAge == 96400 &&
            $0.domain == "docs.chaqmoq.dev" &&
            $0.path == "/get-started" &&
            !$0.isSecure &&
            !$0.isHTTPOnly &&
            $0.sameSite == Cookie.SameSite.none
        }))
        XCTAssertFalse(response.body.isEmpty)
    }

    func testStatuses() {
        // Assert
        for status in Response.Status.allCases {
            let reason = status.reason
            XCTAssertEqual(status.rawValue, status.code)

            switch status {
            case .continue:
                XCTAssertEqual(reason, "Continue")
            case .switchProtocols:
                XCTAssertEqual(reason, "Switch Protocols")
            case .processing:
                XCTAssertEqual(reason, "Processing")
            case .earlyHints:
                XCTAssertEqual(reason, "Early Hints")
            case .ok:
                XCTAssertEqual(reason, "OK")
            case .created:
                XCTAssertEqual(reason, "Created")
            case .accepted:
                XCTAssertEqual(reason, "Accepted")
            case .nonAuthoritativeInformation:
                XCTAssertEqual(reason, "Non-Authoritative Information")
            case .noContent:
                XCTAssertEqual(reason, "No Content")
            case .resetContent:
                XCTAssertEqual(reason, "Reset Content")
            case .partialContent:
                XCTAssertEqual(reason, "Partial Content")
            case .multiStatus:
                XCTAssertEqual(reason, "Multi-Status")
            case .alreadyReported:
                XCTAssertEqual(reason, "Already Reported")
            case .imUsed:
                XCTAssertEqual(reason, "IM Used")
            case .multipleChoices:
                XCTAssertEqual(reason, "Multiple Choices")
            case .movedPermanently:
                XCTAssertEqual(reason, "Moved Permanently")
            case .found:
                XCTAssertEqual(reason, "Found")
            case .seeOther:
                XCTAssertEqual(reason, "See Other")
            case .notModified:
                XCTAssertEqual(reason, "Not Modified")
            case .useProxy:
                XCTAssertEqual(reason, "Use Proxy")
            case .switchProxy:
                XCTAssertEqual(reason, "Switch Proxy")
            case .temporaryRedirect:
                XCTAssertEqual(reason, "Temporary Redirect")
            case .permanentRedirect:
                XCTAssertEqual(reason, "Permanent Redirect")
            case .badRequest:
                XCTAssertEqual(reason, "Bad Request")
            case .unauthorized:
                XCTAssertEqual(reason, "Unauthorized")
            case .paymentRequired:
                XCTAssertEqual(reason, "Payment Required")
            case .forbidden:
                XCTAssertEqual(reason, "Forbidden")
            case .notFound:
                XCTAssertEqual(reason, "Not Found")
            case .methodNotAllowed:
                XCTAssertEqual(reason, "Method Not Allowed")
            case .notAcceptable:
                XCTAssertEqual(reason, "Not Acceptable")
            case .proxyAuthenticationRequired:
                XCTAssertEqual(reason, "Proxy Authentication Required")
            case .requestTimeout:
                XCTAssertEqual(reason, "Request Timeout")
            case .conflict:
                XCTAssertEqual(reason, "Conflict")
            case .gone:
                XCTAssertEqual(reason, "Gone")
            case .lengthRequired:
                XCTAssertEqual(reason, "Length Required")
            case .preconditionFailed:
                XCTAssertEqual(reason, "Precondition Failed")
            case .payloadTooLarge:
                XCTAssertEqual(reason, "Payload Too Large")
            case .uriTooLong:
                XCTAssertEqual(reason, "URI Too Long")
            case .unsupportedMediaType:
                XCTAssertEqual(reason, "Unsupported Media Type")
            case .rangeNotSatisfiable:
                XCTAssertEqual(reason, "Range Not Satisfiable")
            case .expectationFailed:
                XCTAssertEqual(reason, "Expectation Failed")
            case .iAmATeapot:
                XCTAssertEqual(reason, "I'm a teapot")
            case .misdirectedRequest:
                XCTAssertEqual(reason, "Misdirected Request")
            case .unprocessableEntity:
                XCTAssertEqual(reason,  "Unprocessable Entity")
            case .locked:
                XCTAssertEqual(reason, "Locked")
            case .failedDependency:
                XCTAssertEqual(reason, "Failed Dependency")
            case .upgradeRequired:
                XCTAssertEqual(reason, "Upgrade Required")
            case .preconditionRequired:
                XCTAssertEqual(reason, "Precondition Required")
            case .tooManyRequests:
                XCTAssertEqual(reason, "Too Many Requests")
            case .requestHeaderFieldsTooLarge:
                XCTAssertEqual(reason, "Request Header Fields Too Large")
            case .connectionClosedWithoutResponse:
                XCTAssertEqual(reason, "Connection Closed Without Response")
            case .unavailableForLegalReasons:
                XCTAssertEqual(reason, "Unavailable For Legal Reasons")
            case .clientClosedRequest:
                XCTAssertEqual(reason, "Client Closed Request")
            case .internalServerError:
                XCTAssertEqual(reason, "Internal Server Error")
            case .notImplemented:
                XCTAssertEqual(reason, "Not Implemented")
            case .badGateway:
                XCTAssertEqual(reason, "Bad Gateway")
            case .serviceUnavailable:
                XCTAssertEqual(reason, "Service Unavailable")
            case .gatewayTimeout:
                XCTAssertEqual(reason, "Gateway Timeout")
            case .httpVersionNotSupported:
                XCTAssertEqual(reason, "HTTP Version Not Supported")
            case .variantAlsoNegotiates:
                XCTAssertEqual(reason, "Variant Also Negotiates")
            case .insufficientStorage:
                XCTAssertEqual(reason, "Insufficient Storage")
            case .loopDetected:
                XCTAssertEqual(reason, "Loop Detected")
            case .notExtended:
                XCTAssertEqual(reason, "Not Extended")
            case .networkAuthenticationRequired:
                XCTAssertEqual(reason, "Network Authentication Required")
            case .networkConnectTimeout:
                XCTAssertEqual(reason, "Network Connect Timeout")
            }
        }
    }

    func testDescription() {
        // Arrange
        let response = Response()

        // Act
        var description = ""
        for header in response.headers { description.append("\(header.name): \(header.value)\n") }
        description.append("\n\(response.body)")
        description = "\(response.version) \(response.status)\n\(description)"

        // Assert
        XCTAssertEqual("\(response)", description)
        XCTAssertEqual("\(response.status)", "200 OK")
    }

    func testHasCookie() {
        // Arrange
        let response = Response(headers: .init(
            (.setCookie, "sessionId=abcd"),
            (.setCookie, "userId=1")
        ))

        // Assert
        XCTAssertEqual(response.cookies.count, 2)
        XCTAssertTrue(response.hasCookie(named: "sessionId"))
        XCTAssertTrue(response.hasCookie(named: "userId"))
        XCTAssertFalse(response.hasCookie(named: "email"))
        XCTAssertFalse(response.hasCookie(named: "username"))
    }

    func testSetCookie() {
        // Arrange
        var response = Response()

        // Act
        response.setCookie(Cookie(name: "sessionId", value: "abcd"))

        // Assert
        XCTAssertEqual(response.headers.value(for: .setCookie), "sessionId=abcd")
        XCTAssertEqual(response.cookies.count, 1)
        XCTAssertTrue(response.cookies.contains(where: { $0.name == "sessionId" && $0.value == "abcd" }))

        // Act
        response.setCookie(Cookie(name: "sessionId", value: "efgh"))

        // Assert
        XCTAssertEqual(response.headers.value(for: .setCookie), "sessionId=efgh")
        XCTAssertEqual(response.cookies.count, 1)
        XCTAssertTrue(response.cookies.contains(where: { $0.name == "sessionId" && $0.value == "efgh" }))

        // Act
        response.setCookie(Cookie(name: "userId", value: "1"))

        // Assert
        XCTAssertEqual(response.headers.values(for: .setCookie).first, "sessionId=efgh")
        XCTAssertEqual(response.headers.values(for: .setCookie).last, "userId=1")
        XCTAssertEqual(response.cookies.count, 2)
        XCTAssertTrue(response.cookies.contains(where: { $0.name == "sessionId" && $0.value == "efgh" }))
        XCTAssertTrue(response.cookies.contains(where: { $0.name == "userId" && $0.value == "1" }))
    }

    func testClearCookie() {
        // Arrange
        var response = Response(headers: .init(
            (.setCookie, "sessionId=abcd"),
            (.setCookie, "userId=1")
        ))

        // Act
        response.clearCookie(named: "userId")

        // Assert
        XCTAssertEqual(response.cookies.count, 1)
        XCTAssertTrue(response.hasCookie(named: "sessionId"))

        // Act
        response.clearCookie(named: "sessionId")

        // Assert
        XCTAssertTrue(response.cookies.isEmpty)
    }

    func testClearCookies() {
        // Arrange
        var response = Response(headers: .init(
            (.setCookie, "sessionId=abcd"),
            (.setCookie, "userId=1")
        ))

        // Act
        response.clearCookies()

        // Assert
        XCTAssertNil(response.headers.value(for: .setCookie))
        XCTAssertTrue(response.cookies.isEmpty)
    }
}
