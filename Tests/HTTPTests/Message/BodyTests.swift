import XCTest
@testable import HTTP

final class BodyTests: XCTestCase {
    func testInitWithEmptyBytes() {
        // Arrange
        let body = Body()

        // Assert
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
        let body = Body(bytes: bytes)

        // Assert
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
        let body = Body(data: data)

        // Assert
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
        let body = Body(data: data)

        // Assert
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
        let body = Body(string: string)

        // Assert
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
        let body = Body(string: string)

        // Assert
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

    func testDescription() {
        // Arrange
        let string = "Hello World"
        let body = Body(string: string)

        // Assert
        XCTAssertEqual("\(body)", string)
    }
}
