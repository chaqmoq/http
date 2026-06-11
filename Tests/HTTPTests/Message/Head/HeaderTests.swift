@testable import HTTP
import XCTest

final class HeaderTests: XCTestCase {
    func testInit() {
        // Act
        var header = Header(name: "content-type", value: "text/html")

        // Assert
        XCTAssertEqual(header.name, "content-type")
        XCTAssertEqual(header.value, "text/html")

        // Act
        header = Header(name: .connection, value: "keep-alive")

        // Assert
        XCTAssertEqual(header.name, "connection")
        XCTAssertEqual(header.value, "keep-alive")
    }

    func testValueStripsCRLFOnInit() {
        // A value carrying CRLF + an injected header must be flattened to a single line.
        let header = Header(name: .setCookie, value: "id=1\r\nSet-Cookie: admin=true")
        XCTAssertEqual(header.value, "id=1Set-Cookie: admin=true")
        XCTAssertFalse(header.value.contains("\r"))
        XCTAssertFalse(header.value.contains("\n"))
    }

    func testNameStripsCRLFOnInit() {
        let header = Header(name: "x-test\r\nevil", value: "ok")
        XCTAssertEqual(header.name, "x-testevil")
    }

    func testValueStripsControlCharsOnMutation() {
        var header = Header(name: .contentType, value: "text/html")
        header.value = "text/plain\r\nX-Injected: 1\u{00}"
        XCTAssertEqual(header.value, "text/plainX-Injected: 1")
    }

    func testCleanValueIsUnchanged() {
        let header = Header(name: .contentType, value: "application/json; charset=utf-8")
        XCTAssertEqual(header.value, "application/json; charset=utf-8")
    }
}
