@testable import HTTP
import XCTest

final class VersionTests: XCTestCase {
    func testDefaultInit() {
        // Arrange
        let version = Version()

        // Assert
        XCTAssertEqual(version.major, 1)
        XCTAssertEqual(version.minor, 1)
        XCTAssertEqual("\(version)", "HTTP/\(version.major).\(version.minor)")
    }

    func testCustomInit() {
        // Arrange
        let version = Version(major: 2, minor: 0)

        // Assert
        XCTAssertEqual(version.major, 2)
        XCTAssertEqual(version.minor, 0)
        XCTAssertEqual("\(version)", "HTTP/\(version.major).\(version.minor)")
    }

    func testUpdate() {
        // Arrange
        var version = Version(major: 1, minor: 1)

        // Act
        version.major = 2
        version.minor = 0

        // Assert
        XCTAssertEqual(version.major, 2)
        XCTAssertEqual(version.minor, 0)
        XCTAssertEqual("\(version)", "HTTP/\(version.major).\(version.minor)")
    }
}
