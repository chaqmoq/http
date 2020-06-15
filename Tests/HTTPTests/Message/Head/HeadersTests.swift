import XCTest
@testable import HTTP

final class HeadersTests: XCTestCase {
    func testInit() {
        // Act
        let headers = Headers()

        // Assert
        XCTAssertTrue(headers.isEmpty)
    }

    func testInitWithDictionary() {
        // Act
        let headers = Headers([
            .connection: "keep-alive",
            .contentType: "application/json"
        ])

        // Assert
        XCTAssertEqual(headers.count, 2)
        XCTAssertTrue(headers.contains(where: {
            $0.0 == HeaderName.connection.rawValue.lowercased() &&
            $0.1 == "keep-alive"
        }))
        XCTAssertTrue(headers.contains(where: {
            $0.0 == HeaderName.contentType.rawValue.lowercased() &&
            $0.1 == "application/json"
        }))
    }

    func testInitWithTuples() {
        // Act
        let headers = Headers(
            (.acceptCharset, "utf-8, iso-8859-1;q=0.5"),
            (.contentType, "application/xml")
        )

        // Assert
        XCTAssertEqual(headers.count, 2)
        XCTAssertTrue(headers.contains(where: {
            $0.0 == HeaderName.acceptCharset.rawValue.lowercased() &&
            $0.1 == "utf-8, iso-8859-1;q=0.5"
        }))
        XCTAssertTrue(headers.contains(where: {
            $0.0 == HeaderName.contentType.rawValue.lowercased() &&
            $0.1 == "application/xml"
        }))
    }
}
