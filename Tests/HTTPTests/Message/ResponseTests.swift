import XCTest
@testable import HTTP

final class ResponseTests: XCTestCase {
    static var allTests = [
        ("testDescription", testDescription),
        ("testInitWithDefaultValues", testInitWithDefaultValues),
        ("testInitWithCustomValues", testInitWithCustomValues),
        ("testStatuses", testStatuses)
    ]

    func testDescription() {
        // Arrange
        let response = Response()
        var string = ""

        for (header, value) in response.headers {
            string.append("\(header.rawValue): \(value)\n")
        }

        string.append("\n\(response.body)")
        string = "HTTP/\(response.version.major).\(response.version.minor) \(response.status)\n\(string)"

        // Assert
        XCTAssertEqual("\(response)", string)
        XCTAssertEqual("\(response.status)", "200 OK")
    }

    func testInitWithDefaultValues() {
        // Arrange
        let response = Response()

        // Assert
        XCTAssertEqual(response.version.major, 1)
        XCTAssertEqual(response.version.minor, 1)
        XCTAssertEqual(response.status, .ok)
        XCTAssertTrue(response.headers.isEmpty)
        XCTAssertTrue(response.body.isEmpty)
    }

    func testInitWithCustomValues() {
        // Arrange
        let status: Response.Status = .created
        let version: ProtocolVersion = .init(major: 2, minor: 0)
        let headers: ParameterBag<Header, String> = [.contentType: "application/json"]
        let body: Body = .init(string: "{\"title\": \"New post\"}")
        let response = Response(version: version, status: status, headers: headers, body: body)

        // Assert
        XCTAssertEqual(response.version.major, version.major)
        XCTAssertEqual(response.version.minor, version.minor)
        XCTAssertEqual(response.status, status)
        XCTAssertEqual(response.headers, headers)
        XCTAssertFalse(response.body.isEmpty)
    }

    func testStatuses() {
        // Assert
        for status in Response.Status.allCases {
            XCTAssertEqual(status.rawValue, status.code)

            switch status {
            case .continue:
                XCTAssertEqual(status.reason, "Continue")
            case .switchProtocols:
                XCTAssertEqual(status.reason, "Switch Protocols")
            case .processing:
                XCTAssertEqual(status.reason, "Processing")
            case .earlyHints:
                XCTAssertEqual(status.reason, "Early Hints")
            case .ok:
                XCTAssertEqual(status.reason, "OK")
            case .created:
                XCTAssertEqual(status.reason, "Created")
            case .accepted:
                XCTAssertEqual(status.reason, "Accepted")
            case .nonAuthoritativeInformation:
                XCTAssertEqual(status.reason, "Non-Authoritative Information")
            case .noContent:
                XCTAssertEqual(status.reason, "No Content")
            case .resetContent:
                XCTAssertEqual(status.reason, "Reset Content")
            case .partialContent:
                XCTAssertEqual(status.reason, "Partial Content")
            case .multiStatus:
                XCTAssertEqual(status.reason, "Multi-Status")
            case .alreadyReported:
                XCTAssertEqual(status.reason, "Already Reported")
            case .imUsed:
                XCTAssertEqual(status.reason, "IM Used")
            case .multipleChoices:
                XCTAssertEqual(status.reason, "Multiple Choices")
            case .movedPermanently:
                XCTAssertEqual(status.reason, "Moved Permanently")
            case .found:
                XCTAssertEqual(status.reason, "Found")
            case .seeOther:
                XCTAssertEqual(status.reason, "See Other")
            case .notModified:
                XCTAssertEqual(status.reason, "Not Modified")
            case .useProxy:
                XCTAssertEqual(status.reason, "Use Proxy")
            case .switchProxy:
                XCTAssertEqual(status.reason, "Switch Proxy")
            case .temporaryRedirect:
                XCTAssertEqual(status.reason, "Temporary Redirect")
            case .permanentRedirect:
                XCTAssertEqual(status.reason, "Permanent Redirect")
            case .badRequest:
                XCTAssertEqual(status.reason, "Bad Request")
            case .unauthorized:
                XCTAssertEqual(status.reason, "Unauthorized")
            case .paymentRequired:
                XCTAssertEqual(status.reason, "Payment Required")
            case .forbidden:
                XCTAssertEqual(status.reason, "Forbidden")
            case .notFound:
                XCTAssertEqual(status.reason, "Not Found")
            case .methodNotAllowed:
                XCTAssertEqual(status.reason, "Method Not Allowed")
            case .notAcceptable:
                XCTAssertEqual(status.reason, "Not Acceptable")
            case .proxyAuthenticationRequired:
                XCTAssertEqual(status.reason, "Proxy Authentication Required")
            case .requestTimeout:
                XCTAssertEqual(status.reason, "Request Timeout")
            case .conflict:
                XCTAssertEqual(status.reason, "Conflict")
            case .gone:
                XCTAssertEqual(status.reason, "Gone")
            case .lengthRequired:
                XCTAssertEqual(status.reason, "Length Required")
            case .preconditionFailed:
                XCTAssertEqual(status.reason, "Precondition Failed")
            case .payloadTooLarge:
                XCTAssertEqual(status.reason, "Payload Too Large")
            case .uriTooLong:
                XCTAssertEqual(status.reason, "URI Too Long")
            case .unsupportedMediaType:
                XCTAssertEqual(status.reason, "Unsupported Media Type")
            case .rangeNotSatisfiable:
                XCTAssertEqual(status.reason, "Range Not Satisfiable")
            case .expectationFailed:
                XCTAssertEqual(status.reason, "Expectation Failed")
            case .iAmATeapot:
                XCTAssertEqual(status.reason, "I'm a teapot")
            case .misdirectedRequest:
                XCTAssertEqual(status.reason, "Misdirected Request")
            case .unprocessableEntity:
                XCTAssertEqual(status.reason,  "Unprocessable Entity")
            case .locked:
                XCTAssertEqual(status.reason, "Locked")
            case .failedDependency:
                XCTAssertEqual(status.reason, "Failed Dependency")
            case .upgradeRequired:
                XCTAssertEqual(status.reason, "Upgrade Required")
            case .preconditionRequired:
                XCTAssertEqual(status.reason, "Precondition Required")
            case .tooManyRequests:
                XCTAssertEqual(status.reason, "Too Many Requests")
            case .requestHeaderFieldsTooLarge:
                XCTAssertEqual(status.reason, "Request Header Fields Too Large")
            case .connectionClosedWithoutResponse:
                XCTAssertEqual(status.reason, "Connection Closed Without Response")
            case .unavailableForLegalReasons:
                XCTAssertEqual(status.reason, "Unavailable For Legal Reasons")
            case .clientClosedRequest:
                XCTAssertEqual(status.reason, "Client Closed Request")
            case .internalServerError:
                XCTAssertEqual(status.reason, "Internal Server Error")
            case .notImplemented:
                XCTAssertEqual(status.reason, "Not Implemented")
            case .badGateway:
                XCTAssertEqual(status.reason, "Bad Gateway")
            case .serviceUnavailable:
                XCTAssertEqual(status.reason, "Service Unavailable")
            case .gatewayTimeout:
                XCTAssertEqual(status.reason, "Gateway Timeout")
            case .httpVersionNotSupported:
                XCTAssertEqual(status.reason, "HTTP Version Not Supported")
            case .variantAlsoNegotiates:
                XCTAssertEqual(status.reason, "Variant Also Negotiates")
            case .insufficientStorage:
                XCTAssertEqual(status.reason, "Insufficient Storage")
            case .loopDetected:
                XCTAssertEqual(status.reason, "Loop Detected")
            case .notExtended:
                XCTAssertEqual(status.reason, "Not Extended")
            case .networkAuthenticationRequired:
                XCTAssertEqual(status.reason, "Network Authentication Required")
            case .networkConnectTimeout:
                XCTAssertEqual(status.reason, "Network Connect Timeout")
            }
        }
    }
}
