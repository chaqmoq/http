@testable import HTTP
import XCTest

final class DateFormatterTests: XCTestCase {

    func testRFC1123Formatting() {
        // Arrange – a known UTC moment
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15
        components.hour = 12
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(secondsFromGMT: 0)
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!

        // Act
        let formatted = date.rfc1123

        // Assert – Mon, 15 Jan 2024 12:00:00 GMT
        XCTAssertEqual(formatted, "Mon, 15 Jan 2024 12:00:00 GMT")
    }

    func testRFC1123Parsing() {
        // Arrange
        let rfc1123String = "Mon, 15 Jan 2024 12:00:00 GMT"

        // Act
        let date = Date(rfc1123: rfc1123String)

        // Assert – round-trip should produce the same string
        XCTAssertEqual(date.rfc1123, rfc1123String)
    }

    func testRFC1123InvalidStringFallsBackToNow() {
        // Arrange
        let before = Date()

        // Act
        let date = Date(rfc1123: "not a valid date")

        let after = Date()

        // Assert – falls back to current time; must be within the test window
        XCTAssertGreaterThanOrEqual(date.timeIntervalSince1970, before.timeIntervalSince1970 - 1)
        XCTAssertLessThanOrEqual(date.timeIntervalSince1970, after.timeIntervalSince1970 + 1)
    }

    func testSharedFormatterIsSameInstance() {
        // The formatter is a static let, so repeated accesses must return the same object
        let f1 = Date.rfc1123Formatter
        let f2 = Date.rfc1123Formatter
        XCTAssertTrue(f1 === f2)
    }

    func testRoundTrip() {
        // Arrange
        let original = Date()

        // Act
        let formatted = original.rfc1123
        let parsed = Date(rfc1123: formatted)

        // Assert – after round-tripping through the formatter, the dates should be within 1 second
        // (the RFC 1123 format has second precision)
        XCTAssertEqual(formatted, parsed.rfc1123)
    }
}
