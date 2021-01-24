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
}
