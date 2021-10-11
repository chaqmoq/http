@testable import HTTP
import XCTest

final class BodyTests: XCTestCase {
    func testInitWithEmptyBytes() {
        // Act
        let body = Body()

        // Assert
        XCTAssertEqual(body.count, 0)
        XCTAssertTrue(body.isEmpty)
        XCTAssertTrue(body.string.isEmpty)
        XCTAssertTrue(body.data.isEmpty)
        XCTAssertTrue(body.bytes.isEmpty)
    }

    func testInitWithBytes() {
        // Arrange
        let string = "Hello World"
        let data = string.data(using: .utf8)!
        let bytes = [UInt8](data)

        // Act
        let body = Body(bytes: bytes)

        // Assert
        XCTAssertEqual(body.count, string.count)
        XCTAssertFalse(body.isEmpty)
        XCTAssertEqual(body.string, string)
        XCTAssertEqual(body.data, data)
        XCTAssertEqual(body.bytes, bytes)
    }

    func testInitWithEmptyData() {
        // Arrange
        let string = ""
        let data = string.data(using: .utf8)!
        let bytes = [UInt8](data)

        // Act
        let body = Body(data: data)

        // Assert
        XCTAssertEqual(body.count, string.count)
        XCTAssertTrue(body.isEmpty)
        XCTAssertEqual(body.string, string)
        XCTAssertEqual(body.data, data)
        XCTAssertEqual(body.bytes, bytes)
    }

    func testInitWithData() {
        // Arrange
        let string = "Hello World"
        let data = string.data(using: .utf8)!
        let bytes = [UInt8](data)

        // Act
        let body = Body(data: data)

        // Assert
        XCTAssertEqual(body.count, string.count)
        XCTAssertFalse(body.isEmpty)
        XCTAssertEqual(body.string, string)
        XCTAssertEqual(body.data, data)
        XCTAssertEqual(body.bytes, bytes)
    }

    func testInitWithEmptyString() {
        // Arrange
        let string = ""
        let data = string.data(using: .utf8)!
        let bytes = [UInt8](data)

        // Act
        let body = Body(string: string)

        // Assert
        XCTAssertEqual(body.count, string.count)
        XCTAssertTrue(body.isEmpty)
        XCTAssertEqual(body.string, string)
        XCTAssertEqual(body.data, data)
        XCTAssertEqual(body.bytes, bytes)
    }

    func testInitWithString() {
        // Arrange
        let string = "Hello World"
        let data = string.data(using: .utf8)!
        let bytes = [UInt8](data)

        // Act
        let body = Body(string: string)

        // Assert
        XCTAssertEqual(body.count, string.count)
        XCTAssertFalse(body.isEmpty)
        XCTAssertEqual(body.string, string)
        XCTAssertEqual(body.data, data)
        XCTAssertEqual(body.bytes, bytes)
    }

    func testAppendBytes() {
        // Arrange
        let string1 = "Hello"
        let string2 = " World"
        var body = Body(string: string1)

        // Act
        body.append(bytes: [UInt8](string2.data(using: .utf8)!))

        // Assert
        XCTAssertEqual(body.string, "\(string1)\(string2)")
    }

    func testAppendData() {
        // Arrange
        let string1 = "Hello"
        let string2 = " World"
        var body = Body(string: string1)

        // Act
        body.append(data: string2.data(using: .utf8)!)

        // Assert
        XCTAssertEqual(body.string, "\(string1)\(string2)")
    }

    func testAppendString() {
        // Arrange
        let string1 = "Hello"
        let string2 = " World"
        var body = Body(string: string1)

        // Act
        body.append(string: string2)

        // Assert
        XCTAssertEqual(body.string, "\(string1)\(string2)")
    }

    func testEquatable() {
        // Arrange
        let string = "Hello World"

        // Act
        let body1 = Body(string: string)
        let body2 = Body(string: string)

        // Assert
        XCTAssertEqual(body1, body2)
    }

    func testDescription() {
        // Arrange
        let string = "Hello World"
        let body = Body(string: string)

        // Assert
        XCTAssertEqual("\(body)", string)
    }

    func testJSON() {
        // Arrange
        let jsonString = "{\"title\": \"New post\", \"likesCount\": 100}"
        let body = Body(string: jsonString)

        // Act
        let parameters = body.json

        // Assert
        XCTAssertEqual(parameters.count, 2)
        XCTAssertEqual(parameters["title"] as? String, "New post")
        XCTAssertEqual(parameters["likesCount"] as? Int, 100)
    }

    func testURLEncoded() {
        // Arrange
        let urlEncodedString = "title=New+post&likesCount=100"
        let body = Body(string: urlEncodedString)

        // Act
        let parameters = body.urlEncoded

        // Assert
        XCTAssertEqual(parameters.count, 2)
        XCTAssertEqual(parameters["title"], "New post")
        XCTAssertEqual(parameters["likesCount"], "100")
    }
}
