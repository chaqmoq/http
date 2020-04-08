import XCTest
@testable import HTTP

final class ProtocolVersionTests: XCTestCase {
    static var allTests = [
        ("testInitWithDefaultValues", testInitWithDefaultValues),
        ("testInitWithCustomValues", testInitWithCustomValues),
        ("testUpdateValues", testUpdateValues)
    ]

    func testInitWithDefaultValues() {
        // Arrange
        let version = ProtocolVersion()

        // Assert
        XCTAssertEqual(version.major, 1)
        XCTAssertEqual(version.minor, 1)
    }

    func testInitWithCustomValues() {
        // Arrange
        let version = ProtocolVersion(major: 2, minor: 0)

        // Assert
        XCTAssertEqual(version.major, 2)
        XCTAssertEqual(version.minor, 0)
    }

    func testUpdateValues() {
        // Arrange
        var version = ProtocolVersion(major: 1, minor: 1)

        // Act
        version.major = 2
        version.minor = 0

        // Assert
        XCTAssertEqual(version.major, 2)
        XCTAssertEqual(version.minor, 0)
    }
}
