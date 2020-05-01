import XCTest
@testable import struct HTTP.Body

final class BodyFileTests: XCTestCase {
    func testInit() {
        // Arrange
        let filename = "text.txt"
        let data = "Text".data(using: .utf8)!
        let file = Body.File(filename: filename, data: data)

        // Assert
        XCTAssertEqual(file.filename, filename)
        XCTAssertEqual(file.data, data)
    }

    func testUpdate() {
        // Arrange
        let filename = "text2.txt"
        let data = "Another text".data(using: .utf8)!
        var file = Body.File(filename: "text.txt", data: "Text".data(using: .utf8)!)

        file.filename = filename
        file.data = data

        // Assert
        XCTAssertEqual(file.filename, filename)
        XCTAssertEqual(file.data, data)
    }
}
