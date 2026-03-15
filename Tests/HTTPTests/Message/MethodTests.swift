@testable import HTTP
import XCTest

final class MethodTests: XCTestCase {

    func testAllMethodRawValues() {
        // Assert all expected raw string values (case-sensitive)
        XCTAssertEqual(Request.Method.DELETE.rawValue, "DELETE")
        XCTAssertEqual(Request.Method.GET.rawValue, "GET")
        XCTAssertEqual(Request.Method.HEAD.rawValue, "HEAD")
        XCTAssertEqual(Request.Method.OPTIONS.rawValue, "OPTIONS")
        XCTAssertEqual(Request.Method.PATCH.rawValue, "PATCH")
        XCTAssertEqual(Request.Method.POST.rawValue, "POST")
        XCTAssertEqual(Request.Method.PUT.rawValue, "PUT")
        XCTAssertEqual(Request.Method.TRACE.rawValue, "TRACE")
        XCTAssertEqual(Request.Method.CONNECT.rawValue, "CONNECT")
    }

    func testAllCasesCount() {
        // 9 methods: DELETE GET HEAD OPTIONS PATCH POST PUT TRACE CONNECT
        XCTAssertEqual(Request.Method.allCases.count, 9)
    }

    func testInitFromRawValue() {
        XCTAssertEqual(Request.Method(rawValue: "DELETE"), .DELETE)
        XCTAssertEqual(Request.Method(rawValue: "GET"), .GET)
        XCTAssertEqual(Request.Method(rawValue: "HEAD"), .HEAD)
        XCTAssertEqual(Request.Method(rawValue: "OPTIONS"), .OPTIONS)
        XCTAssertEqual(Request.Method(rawValue: "PATCH"), .PATCH)
        XCTAssertEqual(Request.Method(rawValue: "POST"), .POST)
        XCTAssertEqual(Request.Method(rawValue: "PUT"), .PUT)
        XCTAssertEqual(Request.Method(rawValue: "TRACE"), .TRACE)
        XCTAssertEqual(Request.Method(rawValue: "CONNECT"), .CONNECT)
    }

    func testInitFromUnknownRawValueReturnsNil() {
        XCTAssertNil(Request.Method(rawValue: "INVALID"))
        XCTAssertNil(Request.Method(rawValue: "get"))   // case-sensitive
        XCTAssertNil(Request.Method(rawValue: ""))
    }

    func testTRACEMethod() {
        // Arrange
        let eventLoop = EmbeddedEventLoop()

        // Act
        let request = Request(eventLoop: eventLoop, method: .TRACE)

        // Assert
        XCTAssertEqual(request.method, .TRACE)
        XCTAssertEqual(request.method.rawValue, "TRACE")
    }

    func testCONNECTMethod() {
        // Arrange
        let eventLoop = EmbeddedEventLoop()

        // Act
        let request = Request(eventLoop: eventLoop, method: .CONNECT)

        // Assert
        XCTAssertEqual(request.method, .CONNECT)
        XCTAssertEqual(request.method.rawValue, "CONNECT")
    }
}
