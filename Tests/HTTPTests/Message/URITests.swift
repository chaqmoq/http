@testable import HTTP
import XCTest

final class URITests: XCTestCase {
    // MARK: - isValidRequestTarget

    func testValidRequestTargets() {
        XCTAssertTrue(URI.isValidRequestTarget("/"))
        XCTAssertTrue(URI.isValidRequestTarget("/api/v1/posts?page=2"))
        XCTAssertTrue(URI.isValidRequestTarget("/search?q=hello%20world"))
        XCTAssertTrue(URI.isValidRequestTarget("/file%2Fname"))
        XCTAssertTrue(URI.isValidRequestTarget("*"))             // asterisk-form (OPTIONS)
        XCTAssertTrue(URI.isValidRequestTarget("http://example.com/p")) // absolute-form
        XCTAssertTrue(URI.isValidRequestTarget("/emoji/%F0%9F%98%80"))
    }

    func testInvalidRequestTargets() {
        XCTAssertFalse(URI.isValidRequestTarget(""))               // empty
        XCTAssertFalse(URI.isValidRequestTarget("/foo bar"))       // raw space
        XCTAssertFalse(URI.isValidRequestTarget("/foo\tbar"))      // tab
        XCTAssertFalse(URI.isValidRequestTarget("/foo\r\nX: y"))   // CRLF
        XCTAssertFalse(URI.isValidRequestTarget("/foo\u{00}"))     // NUL
        XCTAssertFalse(URI.isValidRequestTarget("/foo\u{7F}"))     // DEL
        XCTAssertFalse(URI.isValidRequestTarget("/foo%zz"))        // bad escape digits
        XCTAssertFalse(URI.isValidRequestTarget("/foo%"))          // truncated escape
        XCTAssertFalse(URI.isValidRequestTarget("/foo%4"))         // one hex digit only
    }

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
        XCTAssertTrue(uri.query.isEmpty)
        XCTAssertNil(uri.fragment)
        XCTAssertEqual("\(uri)", uri.string)
    }

    func testInit() {
        // Arrange
        let string = "http://localhost:8080/posts?id=1#header"

        // Act
        let uri = URI(string)!

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
        let uri = URI("\\:")

        // Assert
        XCTAssertNil(uri)
    }

    func testEquatable() {
        // Arrange
        let string = "http://localhost:8080"

        // Act
        let uri1 = URI(string)
        let uri2 = URI(string)

        // Assert
        XCTAssertEqual(uri1, uri2)
    }
}
