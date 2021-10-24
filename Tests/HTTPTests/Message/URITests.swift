@testable import HTTP
import XCTest

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
        XCTAssertNil(uri.fragment)
        XCTAssertEqual("\(uri)", uri.string)
    }

    func testInit() {
        // Arrange
        let string = "http://localhost:8080/posts?id=1#header"

        // Act
        let uri = URI(string: string)!

        // Assert
        XCTAssertEqual(uri.scheme, "http")
        XCTAssertEqual(uri.host, "localhost")
        XCTAssertEqual(uri.port, 8080)
        XCTAssertEqual(uri.url, URL(string: string))
        XCTAssertEqual(uri.string, string)
        XCTAssertEqual(uri.path, "/posts")
        XCTAssertEqual(uri.query, ["id": "1"])
        XCTAssertEqual(uri.fragment, "header")
        XCTAssertEqual("\(uri)", uri.string)
    }

    func testInvalidInit() {
        // Act
        let uri = URI(string: "\\")

        // Assert
        XCTAssertNil(uri)
    }

    func testEquatable() {
        // Arrange
        let string = "http://localhost:8080"

        // Act
        let uri1 = URI(string: string)
        let uri2 = URI(string: string)

        // Assert
        XCTAssertEqual(uri1, uri2)
    }
}
