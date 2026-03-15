@testable import HTTP
import XCTest

final class RequestAttributeTests: XCTestCase {
    let eventLoop = EmbeddedEventLoop()

    // MARK: - setAttribute / getAttribute

    func testSetAndGetAttributeString() {
        // Arrange
        var request = Request(eventLoop: eventLoop)

        // Act
        request.setAttribute("username", value: "sukhrob")
        let value: String? = request.getAttribute("username")

        // Assert
        XCTAssertEqual(value, "sukhrob")
    }

    func testSetAndGetAttributeInt() {
        // Arrange
        var request = Request(eventLoop: eventLoop)

        // Act
        request.setAttribute("age", value: 30)
        let value: Int? = request.getAttribute("age")

        // Assert
        XCTAssertEqual(value, 30)
    }

    func testSetAndGetAttributeBool() {
        // Arrange
        var request = Request(eventLoop: eventLoop)

        // Act
        request.setAttribute("isAdmin", value: true)
        let value: Bool? = request.getAttribute("isAdmin")

        // Assert
        XCTAssertEqual(value, true)
    }

    func testGetAttributeMissingKeyReturnsNil() {
        // Arrange
        let request = Request(eventLoop: eventLoop)

        // Act
        let value: String? = request.getAttribute("missing")

        // Assert
        XCTAssertNil(value)
    }

    func testSetAttributeNilValue() {
        // Arrange
        var request = Request(eventLoop: eventLoop)
        request.setAttribute("key", value: "initial")

        // Act
        request.setAttribute("key", value: nil)
        let value: String? = request.getAttribute("key")

        // Assert
        // nil is stored as AnyEncodable(nil); cast to String returns nil
        XCTAssertNil(value)
    }

    func testSetAttributeOverwritesExistingValue() {
        // Arrange
        var request = Request(eventLoop: eventLoop)
        request.setAttribute("role", value: "viewer")

        // Act
        request.setAttribute("role", value: "admin")
        let value: String? = request.getAttribute("role")

        // Assert
        XCTAssertEqual(value, "admin")
    }

    func testMultipleAttributesAreIndependent() {
        // Arrange
        var request = Request(eventLoop: eventLoop)

        // Act
        request.setAttribute("a", value: 1)
        request.setAttribute("b", value: "two")
        request.setAttribute("c", value: true)

        let a: Int? = request.getAttribute("a")
        let b: String? = request.getAttribute("b")
        let c: Bool? = request.getAttribute("c")

        // Assert
        XCTAssertEqual(a, 1)
        XCTAssertEqual(b, "two")
        XCTAssertEqual(c, true)
    }

    // MARK: - Locale from Accept-Language header

    func testLocaleFromAcceptLanguageHeader() {
        // Arrange
        let headers: Headers = .init([.acceptLanguage: "uz"])

        // Act
        let request = Request(eventLoop: eventLoop, headers: headers)

        // Assert
        XCTAssertEqual(request.locale, Locale(identifier: "uz"))
    }

    func testLocaleFromAcceptLanguageHeaderPrecedesSystemDefault() {
        // Arrange
        let headers: Headers = .init([.acceptLanguage: "ja"])

        // Act
        let request = Request(eventLoop: eventLoop, headers: headers)

        // Assert
        XCTAssertEqual(request.locale, Locale(identifier: "ja"))
        XCTAssertNotEqual(request.locale, .current)
    }

    func testLocaleDefaultsToCurrentWhenNoAcceptLanguageHeader() {
        // Act
        let request = Request(eventLoop: eventLoop)

        // Assert
        XCTAssertEqual(request.locale, .current)
    }

    func testLocaleExplicitOverridesHeader() {
        // Arrange
        let headers: Headers = .init([.acceptLanguage: "ja"])
        let locale = Locale(identifier: "fr")

        // Act
        let request = Request(eventLoop: eventLoop, headers: headers, locale: locale)

        // Assert
        XCTAssertEqual(request.locale, locale)
    }
}
