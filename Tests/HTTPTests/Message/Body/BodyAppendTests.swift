@testable import HTTP
import Foundation
import XCTest

final class BodyAppendTests: XCTestCase {

    // MARK: - append(bytes:)

    func testAppendBytesToEmptyBody() {
        // Arrange
        var body = Body()
        let bytes: [UInt8] = [72, 101, 108, 108, 111] // "Hello"

        // Act
        body.append(bytes: bytes)

        // Assert
        XCTAssertEqual(body.bytes, bytes)
        XCTAssertEqual(body.string, "Hello")
        XCTAssertEqual(body.count, 5)
    }

    func testAppendBytesToExistingBody() {
        // Arrange
        var body = Body(string: "Hello")
        let extra: [UInt8] = [44, 32, 87, 111, 114, 108, 100] // ", World"

        // Act
        body.append(bytes: extra)

        // Assert
        XCTAssertEqual(body.string, "Hello, World")
    }

    // MARK: - append(data:)

    func testAppendDataToEmptyBody() {
        // Arrange
        var body = Body()
        let data = "Swift".data(using: .utf8)!

        // Act
        body.append(data: data)

        // Assert
        XCTAssertEqual(body.string, "Swift")
        XCTAssertEqual(body.data, data)
    }

    func testAppendDataToExistingBody() {
        // Arrange
        var body = Body(string: "Hello")
        let suffix = " World".data(using: .utf8)!

        // Act
        body.append(data: suffix)

        // Assert
        XCTAssertEqual(body.string, "Hello World")
    }

    // MARK: - append(string:)

    func testAppendStringToEmptyBody() {
        // Arrange
        var body = Body()

        // Act
        body.append(string: "Hello")

        // Assert
        XCTAssertEqual(body.string, "Hello")
        XCTAssertEqual(body.count, 5)
    }

    func testAppendStringToExistingBody() {
        // Arrange
        var body = Body(string: "foo")

        // Act
        body.append(string: "bar")

        // Assert
        XCTAssertEqual(body.string, "foobar")
    }

    func testAppendEmptyString() {
        // Arrange
        var body = Body(string: "initial")

        // Act
        body.append(string: "")

        // Assert
        XCTAssertEqual(body.string, "initial")
    }

    // MARK: - Body.File

    func testBodyFileInit() {
        // Arrange
        let filename = "avatar.png"
        let data = Data([0x89, 0x50, 0x4E, 0x47])

        // Act
        let file = Body.File(filename: filename, data: data)

        // Assert
        XCTAssertEqual(file.filename, filename)
        XCTAssertEqual(file.data, data)
    }

    func testBodyFileIsMutable() {
        // Arrange
        var file = Body.File(filename: "old.txt", data: Data("old".utf8))

        // Act
        file.filename = "new.txt"
        file.data = Data("new".utf8)

        // Assert
        XCTAssertEqual(file.filename, "new.txt")
        XCTAssertEqual(file.data, Data("new".utf8))
    }
}
