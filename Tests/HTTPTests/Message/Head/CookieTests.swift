@testable import HTTP
import XCTest

final class CookieTests: XCTestCase {
    func testInit() {
        // Arrange
        let name = "sessionId"
        let value = "abcd"
        let expires = Date(rfc1123: "Sat, 13 Jun 2020 19:15:12 GMT")
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
        XCTAssertEqual(
            "\(cookie)",
            """
            \(name)=\(value); \
            \(Cookie.OptionName.expires.rawValue)=\(expires.rfc1123); \
            \(Cookie.OptionName.maxAge.rawValue)=\(maxAge); \
            \(Cookie.OptionName.domain.rawValue)=\(domain); \
            \(Cookie.OptionName.path.rawValue)=\(path); \
            \(Cookie.OptionName.isSecure.rawValue); \
            \(Cookie.OptionName.isHTTPOnly.rawValue); \
            \(Cookie.OptionName.sameSite.rawValue)=\(sameSite.rawValue)
            """
        )
    }

    func testOptionName() {
        // Assert
        for optionName in Cookie.OptionName.allCases {
            let rawValue = optionName.rawValue

            switch optionName {
            case .expires:
                XCTAssertEqual(rawValue, "expires")
            case .maxAge:
                XCTAssertEqual(rawValue, "max-age")
            case .domain:
                XCTAssertEqual(rawValue, "domain")
            case .path:
                XCTAssertEqual(rawValue, "path")
            case .isSecure:
                XCTAssertEqual(rawValue, "secure")
            case .isHTTPOnly:
                XCTAssertEqual(rawValue, "httponly")
            case .sameSite:
                XCTAssertEqual(rawValue, "samesite")
            }
        }
    }

    func testSameSite() {
        // Assert
        for sameSite in Cookie.SameSite.allCases {
            let rawValue = sameSite.rawValue

            switch sameSite {
            case .strict:
                XCTAssertEqual(rawValue, "strict")
            case .lax:
                XCTAssertEqual(rawValue, "lax")
            case .none:
                XCTAssertEqual(rawValue, "none")
            }
        }
    }
}
