import XCTest
@testable import struct HTTP.Cookie

final class CookieTests: XCTestCase {
    func testInit() {
        // Arrange
        let name = "sessionId"
        let value = "abcd"
        let expires = Date().addingTimeInterval(3600)
        let maxAge = 7200
        let domain = "chaqmoq.dev"
        let path = "/blog"
        let isSecure = true
        let isHTTPOnly = true
        let sameSite: Cookie.SameSite = .strict

        // Act
        let cookie = Cookie(
            name: name,
            value: value,
            expires: expires,
            maxAge: maxAge,
            domain: domain,
            path: path,
            isSecure: isSecure,
            isHTTPOnly: isHTTPOnly,
            sameSite: sameSite
        )

        // Assert
        XCTAssertEqual(cookie.name, name)
        XCTAssertEqual(cookie.value, value)
        XCTAssertEqual(cookie.expires, expires)
        XCTAssertEqual(cookie.maxAge, maxAge)
        XCTAssertEqual(cookie.domain, domain)
        XCTAssertEqual(cookie.path, path)
        XCTAssertEqual(cookie.isSecure, isSecure)
        XCTAssertEqual(cookie.isHTTPOnly, isHTTPOnly)
        XCTAssertEqual(cookie.sameSite, sameSite)
    }

    func testOptionName() {
        // Assert
        for optionName in Cookie.OptionName.allCases {
            let rawValue = optionName.rawValue

            switch optionName {
            case .expires:
                XCTAssertEqual(rawValue, "Expires")
            case .maxAge:
                XCTAssertEqual(rawValue, "Max-Age")
            case .domain:
                XCTAssertEqual(rawValue, "Domain")
            case .path:
                XCTAssertEqual(rawValue, "Path")
            case .isSecure:
                XCTAssertEqual(rawValue, "Secure")
            case .isHTTPOnly:
                XCTAssertEqual(rawValue, "HttpOnly")
            case .sameSite:
                XCTAssertEqual(rawValue, "SameSite")
            }
        }
    }
}
