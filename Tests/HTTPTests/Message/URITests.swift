import XCTest
@testable import HTTP

final class URITests: XCTestCase {
    func testDefault() {
        // Arrange
        let uri = URI.default

        // Assert
        XCTAssertNil(uri.scheme)
        XCTAssertNil(uri.host)
        XCTAssertNil(uri.port)
        XCTAssertEqual(uri.url, URL(string: "/"))
        XCTAssertEqual(uri.string, "/")
        XCTAssertEqual(uri.path, "/")
        XCTAssertNil(uri.query)
    }
}
