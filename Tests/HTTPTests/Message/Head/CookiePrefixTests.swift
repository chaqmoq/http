@testable import HTTP
import XCTest

/// Tests for the `__Host-` and `__Secure-` cookie prefix rules as defined in
/// https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis
final class CookiePrefixTests: XCTestCase {

    // MARK: - __Host- prefix

    func testHostPrefixForcesSecure() {
        // Arrange / Act
        let cookie = Cookie(name: "__Host-session", value: "abc", isSecure: false)

        // Assert
        XCTAssertTrue(cookie.isSecure, "__Host- cookies must have Secure set")
    }

    func testHostPrefixClearsDomain() {
        // Arrange / Act
        let cookie = Cookie(name: "__Host-session", value: "abc", domain: "example.com")

        // Assert
        XCTAssertNil(cookie.domain, "__Host- cookies must not have a Domain attribute")
    }

    func testHostPrefixSetsPathToRoot() {
        // Arrange / Act
        let cookie = Cookie(name: "__Host-session", value: "abc", path: "/blog")

        // Assert
        XCTAssertEqual(cookie.path, "/", "__Host- cookies must have Path=/")
    }

    func testHostPrefixCaseInsensitive() {
        // Arrange / Act – check both uppercase and mixed-case prefixes
        let upper = Cookie(name: "__HOST-data", value: "1")
        let lower = Cookie(name: "__host-data", value: "2")

        // __host- in lowercase should also be forced (name is lowercased before checking)
        XCTAssertTrue(upper.isSecure)
        XCTAssertNil(upper.domain)
        XCTAssertEqual(upper.path, "/")
        XCTAssertTrue(lower.isSecure)
        XCTAssertNil(lower.domain)
        XCTAssertEqual(lower.path, "/")
    }

    // MARK: - __Secure- prefix

    func testSecurePrefixForcesSecure() {
        // Arrange / Act
        let cookie = Cookie(name: "__Secure-token", value: "xyz", isSecure: false)

        // Assert
        XCTAssertTrue(cookie.isSecure, "__Secure- cookies must have Secure set")
    }

    func testSecurePrefixDoesNotForcePath() {
        // Arrange / Act
        let cookie = Cookie(name: "__Secure-token", value: "xyz", path: "/api")

        // Assert – __Secure- does NOT enforce a specific path
        XCTAssertEqual(cookie.path, "/api")
    }

    func testSecurePrefixDoesNotClearDomain() {
        // Arrange / Act
        let cookie = Cookie(name: "__Secure-token", value: "xyz", domain: "example.com")

        // Assert – __Secure- does NOT clear the domain
        XCTAssertEqual(cookie.domain, "example.com")
    }

    // MARK: - Regular cookie (no prefix)

    func testRegularCookieRespectsCaller() {
        // Arrange / Act
        let cookie = Cookie(
            name: "session",
            value: "abc",
            domain: "example.com",
            path: "/blog",
            isSecure: false,
            isHTTPOnly: true
        )

        // Assert – no prefix means properties are left as-is
        XCTAssertFalse(cookie.isSecure)
        XCTAssertTrue(cookie.isHTTPOnly)
        XCTAssertEqual(cookie.domain, "example.com")
        XCTAssertEqual(cookie.path, "/blog")
    }

    // MARK: - SameSite

    func testSameSiteRawValues() {
        XCTAssertEqual(Cookie.SameSite.strict.rawValue, "strict")
        XCTAssertEqual(Cookie.SameSite.lax.rawValue, "lax")
        XCTAssertEqual(Cookie.SameSite.none.rawValue, "none")
    }

    // MARK: - Description

    func testCookieDescription() {
        // Arrange
        let cookie = Cookie(
            name: "id",
            value: "1",
            maxAge: 3600,
            domain: "example.com",
            path: "/",
            isSecure: true,
            isHTTPOnly: true,
            sameSite: .lax
        )

        let desc = cookie.description

        // Assert
        XCTAssertTrue(desc.hasPrefix("id=1"))
        XCTAssertTrue(desc.contains("max-age=3600"))
        XCTAssertTrue(desc.contains("domain=example.com"))
        XCTAssertTrue(desc.contains("path=/"))
        XCTAssertTrue(desc.contains("secure"))
        XCTAssertTrue(desc.contains("httponly"))
        XCTAssertTrue(desc.contains("samesite=lax"))
    }

    // MARK: - Equatable / Hashable

    func testCookiesWithSameNameAreEqual() {
        let a = Cookie(name: "session", value: "abc")
        let b = Cookie(name: "session", value: "xyz")
        XCTAssertEqual(a, b, "Two cookies with the same name should be equal")
    }

    func testCookiesWithDifferentNamesAreNotEqual() {
        let a = Cookie(name: "session", value: "abc")
        let b = Cookie(name: "token", value: "abc")
        XCTAssertNotEqual(a, b)
    }

    func testCookieSetDeduplicatesByName() {
        var set = Set<Cookie>()
        set.insert(Cookie(name: "session", value: "abc"))
        set.insert(Cookie(name: "session", value: "xyz")) // same name → replaces
        XCTAssertEqual(set.count, 1)
    }
}
