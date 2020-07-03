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
            $0.0 == HeaderName.connection.rawValue &&
            $0.1 == "keep-alive"
        }))
        XCTAssertTrue(headers.contains(where: {
            $0.0 == HeaderName.contentType.rawValue &&
            $0.1 == "application/json"
        }))
    }

    func testInitWithDictionaryHavingKeyOfTypeString() {
        // Act
        let headers: Headers = [
            "connection": "keep-alive",
            "content-type": "text/css"
        ]

        // Assert
        XCTAssertEqual(headers.count, 2)
        XCTAssertTrue(headers.contains(where: {
            $0.0 == HeaderName.connection.rawValue &&
            $0.1 == "keep-alive"
        }))
        XCTAssertTrue(headers.contains(where: {
            $0.0 == HeaderName.contentType.rawValue &&
            $0.1 == "text/css"
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
            $0.0 == HeaderName.acceptCharset.rawValue &&
            $0.1 == "utf-8, iso-8859-1;q=0.5"
        }))
        XCTAssertTrue(headers.contains(where: {
            $0.0 == HeaderName.contentType.rawValue &&
            $0.1 == "application/xml"
        }))
    }

    func testInitWithTuplesHavingKeyTypeOfString() {
        // Act
        let headers = Headers(
            ("accept-charset", "utf-8, iso-8859-1;q=0.8"),
            ("content-type", "text/plain")
        )

        // Assert
        XCTAssertEqual(headers.count, 2)
        XCTAssertTrue(headers.contains(where: {
            $0.0 == HeaderName.acceptCharset.rawValue &&
            $0.1 == "utf-8, iso-8859-1;q=0.8"
        }))
        XCTAssertTrue(headers.contains(where: {
            $0.0 == HeaderName.contentType.rawValue &&
            $0.1 == "text/plain"
        }))
    }

    func testIndices() {
        // Arrange
        let headers = Headers(
            (.setCookie, "sessionId=abc"),
            (.contentType, "application/js"),
            (.setCookie, "userId=1")
        )

        // Act
        let indices = headers.indices(for: .setCookie)

        // Assert
        XCTAssertEqual(headers.count, 3)
        XCTAssertEqual(indices.first, 0)
        XCTAssertEqual(indices.last, 2)
    }

    func testAdd() {
        // Arrange
        var headers: Headers = ["content-type": "text/css"]

        // Act
        headers.add("text/html", for: .contentType)

        // Assert
        XCTAssertEqual(headers.count, 2)
        XCTAssertEqual(headers.value(for: .contentType), "text/html")
    }
}
