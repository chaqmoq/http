import XCTest
@testable import HTTP

final class HeadersTests: XCTestCase {
    func testInit() {
        // Act
        let headers = Headers()

        // Assert
        XCTAssertTrue(headers.isEmpty)
    }
}
