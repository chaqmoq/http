@testable import HTTP
import XCTest

final class HeadersTests: XCTestCase {
    func testInit() {
        // Act
        let headers = Headers()

        // Assert
        XCTAssertTrue(headers.isEmpty)
    }

    func testInitWithDictionary() {
        // Act
        let headers = Headers([.connection: "keep-alive", .contentType: "application/json"])

        // Assert
        XCTAssertEqual(headers.count, 2)
        XCTAssertTrue(headers.contains(where: { $0.name == HeaderName.connection.rawValue && $0.value == "keep-alive" }))
        XCTAssertTrue(headers.contains(where: {
            $0.name == HeaderName.contentType.rawValue && $0.value == "application/json"
        }))
    }

    func testInitWithDictionaryHavingKeyOfStringType() {
        // Act
        let headers: Headers = ["connection": "keep-alive", "content-type": "text/css"]

        // Assert
        XCTAssertEqual(headers.count, 2)
        XCTAssertTrue(headers.contains(where: { $0.name == HeaderName.connection.rawValue && $0.value == "keep-alive" }))
        XCTAssertTrue(headers.contains(where: { $0.name == HeaderName.contentType.rawValue && $0.value == "text/css" }))
    }

    func testInitWithTuples() {
        // Act
        let headers = Headers((.acceptCharset, "utf-8, iso-8859-1;q=0.5"), (.contentType, "application/xml"))

        // Assert
        XCTAssertEqual(headers.count, 2)
        XCTAssertTrue(headers.contains(where: {
            $0.name == HeaderName.acceptCharset.rawValue && $0.value == "utf-8, iso-8859-1;q=0.5"
        }))
        XCTAssertTrue(headers.contains(where: {
            $0.name == HeaderName.contentType.rawValue && $0.value == "application/xml"
        }))
    }

    func testInitWithTuplesHavingKeyOfStringType() {
        // Act
        let headers = Headers(("accept-charset", "utf-8, iso-8859-1;q=0.8"), ("content-type", "text/plain"))

        // Assert
        XCTAssertEqual(headers.count, 2)
        XCTAssertTrue(headers.contains(where: {
            $0.name == HeaderName.acceptCharset.rawValue && $0.value == "utf-8, iso-8859-1;q=0.8"
        }))
        XCTAssertTrue(headers.contains(where: { $0.name == HeaderName.contentType.rawValue && $0.value == "text/plain" }))
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

    func testSet() {
        // Arrange
        var headers: Headers = ["content-type": "text/html"]

        // Act
        headers.set("text/css", for: .contentType)

        // Assert
        XCTAssertEqual(headers.count, 1)
        XCTAssertEqual(headers.value(for: .contentType), "text/css")

        // Act
        headers.set("close", for: .connection)

        // Assert
        XCTAssertEqual(headers.count, 2)
        XCTAssertEqual(headers.value(for: .contentType), "text/css")
        XCTAssertEqual(headers.value(for: .connection), "close")

        // Act
        headers[0] = Header(name: HeaderName.contentType, value: "text/plain")

        // Assert
        XCTAssertEqual(headers.count, 2)
        XCTAssertEqual(headers.value(for: .contentType), "text/plain")
        XCTAssertEqual(headers.value(for: .connection), "close")
    }

    func testRemoveByName() {
        // Arrange
        var headers = Headers([.connection: "keep-alive", .contentType: "application/json"])

        // Act
        headers.remove(.connection)

        // Assert
        XCTAssertEqual(headers.count, 1)
        XCTAssertTrue(headers.contains(where: {
            $0.name == HeaderName.contentType.rawValue && $0.value == "application/json"
        }))

        // Act
        headers.remove(.contentType)

        // Assert
        XCTAssertTrue(headers.isEmpty)
    }

    func testRemoveAtIndex() {
        // Arrange
        var headers = Headers((.connection, "keep-alive"), (.contentType, "application/json"))

        // Act
        headers.remove(at: 1)

        // Assert
        XCTAssertEqual(headers.count, 1)
        XCTAssertTrue(headers.contains(where: {
            $0.name == HeaderName.connection.rawValue && $0.value == "keep-alive"
        }))

        // Act
        headers.remove(at: 0)

        // Assert
        XCTAssertTrue(headers.isEmpty)
    }

    func testHas() {
        // Arrange
        let headers: Headers = ["content-type": "text/html"]

        // Act/Assert
        XCTAssertTrue(headers.has(.contentType))
    }

    func testValuesByName() {
        // Arrange
        let headers = Headers([.connection: "close", .contentType: "application/javascript"])

        // Act
        let connectionValues = headers.values(for: .connection)
        let contentTypeValues = headers.values(for: .contentType)

        // Assert
        XCTAssertEqual(connectionValues.count, 1)
        XCTAssertEqual(connectionValues.first, "close")
        XCTAssertEqual(contentTypeValues.count, 1)
        XCTAssertEqual(contentTypeValues.first, "application/javascript")
    }
}
