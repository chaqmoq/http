@testable import HTTP
import XCTest

final class CORSMiddlewareTests: XCTestCase {
    let eventLoop = EmbeddedEventLoop()

    // MARK: - Non-CORS requests (no Origin header)

    func testNonCORSRequestPassesThrough() async throws {
        // Arrange
        let middleware = CORSMiddleware()
        let request = Request(eventLoop: eventLoop)

        // Act
        let response = try await middleware.handle(request: request) { _ in
            Response("body")
        }

        // Assert – should get the responder's response unchanged
        XCTAssertEqual((response as? Response)?.body.string, "body")
    }

    // MARK: - Simple CORS request (all origins)

    func testAllOriginsAllowed() async throws {
        // Arrange
        let middleware = CORSMiddleware(options: .init(allowedOrigin: .all))
        var request = Request(eventLoop: eventLoop)
        request.headers.set(.init(name: .origin, value: "https://example.com"))

        // Act
        let encodable = try await middleware.handle(request: request) { _ in Response() }
        let response = try XCTUnwrap(encodable as? Response)

        // Assert
        XCTAssertEqual(response.headers.get(.accessControlAllowOrigin), "*")
    }

    func testNoOriginAllowed() async throws {
        // Arrange
        let middleware = CORSMiddleware(options: .init(allowedOrigin: .none))
        var request = Request(eventLoop: eventLoop)
        request.headers.set(.init(name: .origin, value: "https://evil.com"))

        // Act
        let encodable = try await middleware.handle(request: request) { _ in Response() }
        let response = try XCTUnwrap(encodable as? Response)

        // Assert
        XCTAssertEqual(response.headers.get(.accessControlAllowOrigin), "")
    }

    func testSpecificOriginsAllowed() async throws {
        // Arrange
        let allowed = "https://allowed.com"
        let middleware = CORSMiddleware(options: .init(allowedOrigin: .origins([allowed])))

        // Act – allowed origin
        var request = Request(eventLoop: eventLoop)
        request.headers.set(.init(name: .origin, value: allowed))
        let allowedResponse = try await middleware.handle(request: request) { _ in Response() }
        XCTAssertEqual((allowedResponse as? Response)?.headers.get(.accessControlAllowOrigin), allowed)

        // Act – disallowed origin
        var blockedRequest = Request(eventLoop: eventLoop)
        blockedRequest.headers.set(.init(name: .origin, value: "https://evil.com"))
        let blockedResponse = try await middleware.handle(request: blockedRequest) { _ in Response() }
        XCTAssertEqual((blockedResponse as? Response)?.headers.get(.accessControlAllowOrigin), "false")
    }

    func testSameAsOriginReflectsOriginAndSetsVary() async throws {
        // Arrange
        let origin = "https://myapp.com"
        let middleware = CORSMiddleware(options: .init(allowedOrigin: .sameAsOrigin))
        var request = Request(eventLoop: eventLoop)
        request.headers.set(.init(name: .origin, value: origin))

        // Act
        let encodable = try await middleware.handle(request: request) { _ in Response() }
        let response = try XCTUnwrap(encodable as? Response)

        // Assert
        XCTAssertEqual(response.headers.get(.accessControlAllowOrigin), origin)
        XCTAssertEqual(response.headers.get(.vary), "Origin")
    }

    func testOriginsAndRegexSetVaryOrigin() async throws {
        // Allowlist and regex matches both derive ACAO from the request Origin, so the
        // response must carry `Vary: Origin` to be cache-safe.
        let allowlist = CORSMiddleware(options: .init(allowedOrigin: .origins(["https://myapp.com"])))
        var allowlistRequest = Request(eventLoop: eventLoop)
        allowlistRequest.headers.set(.init(name: .origin, value: "https://myapp.com"))
        let allowlistResponse = try await allowlist.handle(request: allowlistRequest) { _ in Response() }
        XCTAssertEqual((allowlistResponse as? Response)?.headers.get(.vary), "Origin")

        let regex = CORSMiddleware(options: .init(allowedOrigin: .regex("https://.*\\.example\\.com")))
        var regexRequest = Request(eventLoop: eventLoop)
        regexRequest.headers.set(.init(name: .origin, value: "https://sub.example.com"))
        let regexResponse = try await regex.handle(request: regexRequest) { _ in Response() }
        XCTAssertEqual((regexResponse as? Response)?.headers.get(.vary), "Origin")
    }

    func testAllOriginDoesNotSetVary() async throws {
        // A fixed "*" value does not depend on the request Origin, so no Vary is needed.
        let middleware = CORSMiddleware(options: .init(allowedOrigin: .all))
        var request = Request(eventLoop: eventLoop)
        request.headers.set(.init(name: .origin, value: "https://myapp.com"))
        let response = try await middleware.handle(request: request) { _ in Response() }
        XCTAssertNil((response as? Response)?.headers.get(.vary))
    }

    func testVaryOriginPreservesExistingVaryHeader() async throws {
        // Adding Origin must not clobber a Vary value the handler already set.
        let middleware = CORSMiddleware(options: .init(allowedOrigin: .sameAsOrigin))
        var request = Request(eventLoop: eventLoop)
        request.headers.set(.init(name: .origin, value: "https://myapp.com"))
        let response = try await middleware.handle(request: request) { _ in
            var response = Response()
            response.headers.set(.init(name: .vary, value: "Accept-Encoding"))
            return response
        }
        XCTAssertEqual((response as? Response)?.headers.get(.vary), "Accept-Encoding, Origin")
    }

    // MARK: - Credentials

    func testAllowCredentialsHeader() async throws {
        // Credentials are advertised only when paired with a specific (non-wildcard)
        // origin, so this uses an explicit allowlist.
        let middleware = CORSMiddleware(options: .init(
            allowCredentials: true,
            allowedOrigin: .origins(["https://example.com"])
        ))
        var request = Request(eventLoop: eventLoop)
        request.headers.set(.init(name: .origin, value: "https://example.com"))

        // Act
        let encodable = try await middleware.handle(request: request) { _ in Response() }
        let response = try XCTUnwrap(encodable as? Response)

        // Assert
        XCTAssertEqual(response.headers.get(.accessControlAllowCredentials), "true")
    }

    func testNoAllowCredentialsHeaderWithWildcardOrigin() async throws {
        // The CORS spec forbids credentials + "*". With `.all`, the credentials header
        // must be suppressed rather than emitted alongside the wildcard origin.
        let middleware = CORSMiddleware(options: .init(allowCredentials: true, allowedOrigin: .all))
        var request = Request(eventLoop: eventLoop)
        request.headers.set(.init(name: .origin, value: "https://example.com"))

        let response = try await middleware.handle(request: request) { _ in Response() }
        XCTAssertEqual((response as? Response)?.headers.get(.accessControlAllowOrigin), "*")
        XCTAssertNil((response as? Response)?.headers.get(.accessControlAllowCredentials))
    }

    func testNoAllowCredentialsHeaderWhenOriginNotAllowed() async throws {
        // When an allowlist does not match, ACAO is the "false" sentinel and credentials
        // must not be advertised.
        let middleware = CORSMiddleware(options: .init(
            allowCredentials: true,
            allowedOrigin: .origins(["https://example.com"])
        ))
        var request = Request(eventLoop: eventLoop)
        request.headers.set(.init(name: .origin, value: "https://evil.com"))

        let response = try await middleware.handle(request: request) { _ in Response() }
        XCTAssertNil((response as? Response)?.headers.get(.accessControlAllowCredentials))
    }

    func testNoAllowCredentialsHeaderWhenFalse() async throws {
        // Arrange
        let middleware = CORSMiddleware(options: .init(allowCredentials: false))
        var request = Request(eventLoop: eventLoop)
        request.headers.set(.init(name: .origin, value: "https://example.com"))

        // Act
        let encodable = try await middleware.handle(request: request) { _ in Response() }
        let response = try XCTUnwrap(encodable as? Response)

        // Assert
        XCTAssertNil(response.headers.get(.accessControlAllowCredentials))
    }

    // MARK: - Allowed Methods

    func testAllowMethodsHeader() async throws {
        // Arrange
        let methods: [Request.Method] = [.GET, .POST]
        let middleware = CORSMiddleware(options: .init(allowedMethods: methods))
        var request = Request(eventLoop: eventLoop)
        request.headers.set(.init(name: .origin, value: "https://example.com"))

        // Act
        let encodable = try await middleware.handle(request: request) { _ in Response() }
        let response = try XCTUnwrap(encodable as? Response)

        // Assert
        let headerValue = try XCTUnwrap(response.headers.get(.accessControlAllowMethods))
        XCTAssertTrue(headerValue.contains("GET"))
        XCTAssertTrue(headerValue.contains("POST"))
    }

    // MARK: - Allowed Headers

    func testExplicitAllowedHeadersHeader() async throws {
        // Arrange
        let middleware = CORSMiddleware(options: .init(allowedHeaders: ["X-Custom-Header", "Authorization"]))
        var request = Request(eventLoop: eventLoop)
        request.headers.set(.init(name: .origin, value: "https://example.com"))

        // Act
        let encodable = try await middleware.handle(request: request) { _ in Response() }
        let response = try XCTUnwrap(encodable as? Response)

        // Assert
        let value = try XCTUnwrap(response.headers.get(.accessControlAllowHeaders))
        XCTAssertTrue(value.contains("X-Custom-Header"))
        XCTAssertTrue(value.contains("Authorization"))
    }

    func testReflectRequestedHeaders() async throws {
        // Arrange – no explicit allowedHeaders, should reflect the request header
        let middleware = CORSMiddleware(options: .init(allowedHeaders: nil))
        var request = Request(eventLoop: eventLoop)
        request.headers.set(.init(name: .origin, value: "https://example.com"))
        request.headers.set(.init(name: .accessControlRequestHeaders, value: "X-My-Header"))

        // Act
        let encodable = try await middleware.handle(request: request) { _ in Response() }
        let response = try XCTUnwrap(encodable as? Response)

        // Assert
        XCTAssertEqual(response.headers.get(.accessControlAllowHeaders), "X-My-Header")
    }

    // MARK: - Max Age

    func testMaxAgeHeader() async throws {
        // Arrange
        let middleware = CORSMiddleware(options: .init(maxAge: 3600))
        var request = Request(eventLoop: eventLoop)
        request.headers.set(.init(name: .origin, value: "https://example.com"))

        // Act
        let encodable = try await middleware.handle(request: request) { _ in Response() }
        let response = try XCTUnwrap(encodable as? Response)

        // Assert
        XCTAssertEqual(response.headers.get(.accessControlMaxAge), "3600")
    }

    // MARK: - Exposed Headers

    func testExposeHeadersHeader() async throws {
        // Arrange
        let middleware = CORSMiddleware(options: .init(exposedHeaders: ["X-Rate-Limit"]))
        var request = Request(eventLoop: eventLoop)
        request.headers.set(.init(name: .origin, value: "https://example.com"))

        // Act
        let encodable = try await middleware.handle(request: request) { _ in Response() }
        let response = try XCTUnwrap(encodable as? Response)

        // Assert
        XCTAssertEqual(response.headers.get(.accessControlExposeHeaders), "X-Rate-Limit")
    }

    // MARK: - Preflight

    func testPreflightReturns204() async throws {
        // Arrange
        let middleware = CORSMiddleware()
        var request = Request(eventLoop: eventLoop, method: .OPTIONS)
        request.headers.set(.init(name: .origin, value: "https://example.com"))
        request.headers.set(.init(name: .accessControlRequestMethod, value: "POST"))

        // Act
        let encodable = try await middleware.handle(request: request) { _ in
            // This should NOT be called for a preflight
            XCTFail("Responder should not be called for a preflight request")
            return Response()
        }
        let response = try XCTUnwrap(encodable as? Response)

        // Assert
        XCTAssertEqual(response.status, .noContent)
    }

    func testNonPreflightOptionsRequestPassesThrough() async throws {
        // Arrange – OPTIONS without Access-Control-Request-Method is NOT a preflight
        let middleware = CORSMiddleware()
        var request = Request(eventLoop: eventLoop, method: .OPTIONS)
        request.headers.set(.init(name: .origin, value: "https://example.com"))
        // No Access-Control-Request-Method header

        var responderCalled = false
        let encodable = try await middleware.handle(request: request) { _ in
            responderCalled = true
            return Response(status: .ok)
        }
        let response = try XCTUnwrap(encodable as? Response)

        // Assert
        XCTAssertTrue(responderCalled)
        XCTAssertEqual(response.status, .ok)
    }

    // MARK: - Regex allowed origin

    func testRegexAllowedOrigin() async throws {
        // Arrange
        let middleware = CORSMiddleware(options: .init(allowedOrigin: .regex("https://.*\\.example\\.com")))

        var matchingRequest = Request(eventLoop: eventLoop)
        matchingRequest.headers.set(.init(name: .origin, value: "https://sub.example.com"))
        let matchingResponse = try await middleware.handle(request: matchingRequest) { _ in Response() }
        XCTAssertEqual(
            (matchingResponse as? Response)?.headers.get(.accessControlAllowOrigin),
            "https://sub.example.com"
        )

        var nonMatchingRequest = Request(eventLoop: eventLoop)
        nonMatchingRequest.headers.set(.init(name: .origin, value: "https://evil.com"))
        let nonMatchingResponse = try await middleware.handle(request: nonMatchingRequest) { _ in Response() }
        XCTAssertEqual(
            (nonMatchingResponse as? Response)?.headers.get(.accessControlAllowOrigin),
            "false"
        )
    }

    func testRegexAllowedOriginRejectsSubstringMatches() async throws {
        // The pattern is anchored to the full Origin, so an attacker origin that merely
        // *contains* a trusted origin as a substring must not be allowed.
        let middleware = CORSMiddleware(options: .init(allowedOrigin: .regex("https://app\\.example\\.com")))

        // Trailing-domain suffix: "https://app.example.com.evil.com"
        var suffixRequest = Request(eventLoop: eventLoop)
        suffixRequest.headers.set(.init(name: .origin, value: "https://app.example.com.evil.com"))
        let suffixResponse = try await middleware.handle(request: suffixRequest) { _ in Response() }
        XCTAssertEqual(
            (suffixResponse as? Response)?.headers.get(.accessControlAllowOrigin),
            "false"
        )

        // Trusted origin embedded as a query/path substring.
        var embeddedRequest = Request(eventLoop: eventLoop)
        embeddedRequest.headers.set(.init(name: .origin, value: "https://evil.com/?x=https://app.example.com"))
        let embeddedResponse = try await middleware.handle(request: embeddedRequest) { _ in Response() }
        XCTAssertEqual(
            (embeddedResponse as? Response)?.headers.get(.accessControlAllowOrigin),
            "false"
        )

        // The exact trusted origin still matches.
        var exactRequest = Request(eventLoop: eventLoop)
        exactRequest.headers.set(.init(name: .origin, value: "https://app.example.com"))
        let exactResponse = try await middleware.handle(request: exactRequest) { _ in Response() }
        XCTAssertEqual(
            (exactResponse as? Response)?.headers.get(.accessControlAllowOrigin),
            "https://app.example.com"
        )
    }

    // MARK: - ErrorMiddleware

    func testCORSHeadersAppliedToErrorResponse() async throws {
        // Arrange
        let middleware = CORSMiddleware(options: .init(allowedOrigin: .all))
        var request = Request(eventLoop: eventLoop)
        request.headers.set(.init(name: .origin, value: "https://example.com"))

        struct TestError: Error {}

        // Act
        let encodable = try await middleware.handle(request: request, error: TestError()) { _, _ in
            Response(status: .internalServerError)
        }
        let response = try XCTUnwrap(encodable as? Response)

        // Assert – CORS headers must be present even on error responses
        XCTAssertEqual(response.status, .internalServerError)
        XCTAssertEqual(response.headers.get(.accessControlAllowOrigin), "*")
    }

    func testErrorResponseWithoutOriginPassesThrough() async throws {
        // Arrange – no Origin header, so the error responder result is returned unchanged
        let middleware = CORSMiddleware(options: .init(allowedOrigin: .all))
        let request = Request(eventLoop: eventLoop)

        struct TestError: Error {}

        // Act
        let encodable = try await middleware.handle(request: request, error: TestError()) { _, _ in
            Response(status: .internalServerError)
        }
        let response = try XCTUnwrap(encodable as? Response)

        // Assert – no CORS header injected
        XCTAssertEqual(response.status, .internalServerError)
        XCTAssertNil(response.headers.get(.accessControlAllowOrigin))
    }

    // MARK: - Non-Response Encodable from responder is wrapped in a Response

    /// When the downstream responder returns a non-`Response` `Encodable` the CORS
    /// handler must still apply its headers. Exercises the
    /// `encodable as? Response ?? .init("\(encodable)")` branch in `handle`.
    func testHandleWrapsNonResponseEncodableFromResponder() async throws {
        let middleware = CORSMiddleware(options: .init(allowedOrigin: .all))
        var request = Request(eventLoop: eventLoop)
        request.headers.set(.init(name: .origin, value: "https://example.com"))

        // Return a plain String (not a Response) from the responder
        let result = try await middleware.handle(request: request) { _ in
            "plain string body" as Encodable
        }

        let response = try XCTUnwrap(result as? Response)
        XCTAssertEqual(response.body.string, "plain string body")
        XCTAssertEqual(response.headers.get(.accessControlAllowOrigin), "*")
    }
}
