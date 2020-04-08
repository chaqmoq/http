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
}
