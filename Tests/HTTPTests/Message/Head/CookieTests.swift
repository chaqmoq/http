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

    func testInitHostPrefixForName() {
        // Arrange
        let name = "__Host-sessionId"
        let value = "efgh"
        let expires = Date(rfc1123: "Sun, 14 Jun 2020 07:45:13 GMT")
        let maxAge = 3600
        let domain = "chaqmoq.dev"
        let path = "/posts"
        let isSecure = false
        let isHTTPOnly = false
        let sameSite: Cookie.SameSite = .lax

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
        XCTAssertNil(cookie.domain)
        XCTAssertEqual(cookie.path, Cookie.path)
        XCTAssertEqual(cookie.isSecure, true)
        XCTAssertEqual(cookie.isHTTPOnly, isHTTPOnly)
        XCTAssertEqual(cookie.sameSite, sameSite)
        XCTAssertEqual(
            "\(cookie)",
            """
            \(name)=\(value); \
            \(Cookie.OptionName.expires.rawValue)=\(expires.rfc1123); \
            \(Cookie.OptionName.maxAge.rawValue)=\(maxAge); \
            \(Cookie.OptionName.path.rawValue)=\(Cookie.path); \
            \(Cookie.OptionName.isSecure.rawValue); \
            \(Cookie.OptionName.sameSite.rawValue)=\(sameSite.rawValue)
            """
        )
    }

    func testInitSecurePrefixForName() {
        // Arrange
        let name = "__Secure-sessionId"
        let value = "ijkl"
        let expires = Date(rfc1123: "Mon, 15 Jun 2020 23:01:26 GMT")
        let maxAge = 4800
        let domain = "chaqmoq.dev"
        let path = "/about"
        let isSecure = false
        let isHTTPOnly = true
        let sameSite: Cookie.SameSite = .none

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
        XCTAssertEqual(cookie.isSecure, true)
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

    func testEquatable() {
        // Arrange
        let name = "sessionId"

        // Act
        let cookie1 = Cookie(name: name, value: "abcd")
        let cookie2 = Cookie(name: name, value: "efgh")

        // Assert
        XCTAssertEqual(cookie1, cookie2)
    }

    func testHashable() {
        // Arrange
        let cookie1 = Cookie(name: "sessionId", value: "abcd")
        let cookie2 = Cookie(name: "username", value: "chaqmoq")

        // Act
        let cookies: Set<Cookie> = [cookie1, cookie2]

        // Assert
        XCTAssertEqual(cookies.count, 2)
        XCTAssertTrue(cookies.contains(cookie1))
        XCTAssertTrue(cookies.contains(cookie2))
    }
}
