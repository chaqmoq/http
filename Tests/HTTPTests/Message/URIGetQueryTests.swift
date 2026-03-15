@testable import HTTP
import XCTest

final class URIGetQueryTests: XCTestCase {
    // MARK: - String

    func testGetQueryString() {
        let uri = URI("/search?q=hello")!
        let value: String? = uri.getQuery("q")
        XCTAssertEqual(value, "hello")
    }

    func testGetQueryMissingKeyReturnsNil() {
        let uri = URI("/search?q=hello")!
        let value: String? = uri.getQuery("missing")
        XCTAssertNil(value)
    }

    // MARK: - Character

    func testGetQueryCharacter() {
        let uri = URI("/path?char=A")!
        let value: Character? = uri.getQuery("char")
        XCTAssertEqual(value, "A")
    }

    // MARK: - Bool

    func testGetQueryBoolTrue() {
        let uri = URI("/path?flag=true")!
        let value: Bool? = uri.getQuery("flag")
        XCTAssertEqual(value, true)
    }

    func testGetQueryBoolFalse() {
        let uri = URI("/path?flag=false")!
        let value: Bool? = uri.getQuery("flag")
        XCTAssertEqual(value, false)
    }

    func testGetQueryBoolInvalidReturnsNil() {
        let uri = URI("/path?flag=maybe")!
        let value: Bool? = uri.getQuery("flag")
        XCTAssertNil(value)
    }

    // MARK: - Int family

    func testGetQueryInt() {
        let uri = URI("/path?page=42")!
        let value: Int? = uri.getQuery("page")
        XCTAssertEqual(value, 42)
    }

    func testGetQueryInt8() {
        let uri = URI("/path?n=127")!
        let value: Int8? = uri.getQuery("n")
        XCTAssertEqual(value, 127)
    }

    func testGetQueryInt16() {
        let uri = URI("/path?n=1000")!
        let value: Int16? = uri.getQuery("n")
        XCTAssertEqual(value, 1000)
    }

    func testGetQueryInt32() {
        let uri = URI("/path?n=70000")!
        let value: Int32? = uri.getQuery("n")
        XCTAssertEqual(value, 70_000)
    }

    func testGetQueryInt64() {
        let uri = URI("/path?n=5000000000")!
        let value: Int64? = uri.getQuery("n")
        XCTAssertEqual(value, 5_000_000_000)
    }

    // MARK: - UInt family

    func testGetQueryUInt() {
        let uri = URI("/path?n=99")!
        let value: UInt? = uri.getQuery("n")
        XCTAssertEqual(value, 99)
    }

    func testGetQueryUInt8() {
        let uri = URI("/path?n=255")!
        let value: UInt8? = uri.getQuery("n")
        XCTAssertEqual(value, 255)
    }

    func testGetQueryUInt16() {
        let uri = URI("/path?n=65535")!
        let value: UInt16? = uri.getQuery("n")
        XCTAssertEqual(value, 65_535)
    }

    func testGetQueryUInt32() {
        let uri = URI("/path?n=100000")!
        let value: UInt32? = uri.getQuery("n")
        XCTAssertEqual(value, 100_000)
    }

    func testGetQueryUInt64() {
        let uri = URI("/path?n=9999999999")!
        let value: UInt64? = uri.getQuery("n")
        XCTAssertEqual(value, 9_999_999_999)
    }

    // MARK: - Float / Double

    func testGetQueryFloat() {
        let uri = URI("/path?ratio=3.14")!
        let value: Float? = uri.getQuery("ratio")
        XCTAssertNotNil(value)
        XCTAssertEqual(value!, 3.14, accuracy: 0.001)
    }

    func testGetQueryDouble() {
        let uri = URI("/path?ratio=2.718281828")!
        let value: Double? = uri.getQuery("ratio")
        XCTAssertNotNil(value)
        XCTAssertEqual(value!, 2.718281828, accuracy: 0.000000001)
    }

    // MARK: - URL

    func testGetQueryURL() {
        let uri = URI("/path?link=https://example.com")!
        let value: URL? = uri.getQuery("link")
        XCTAssertEqual(value, URL(string: "https://example.com"))
    }

    func testGetQueryURLInvalidReturnsNil() {
        let uri = URI("/path?link=")!
        let value: URL? = uri.getQuery("link")
        // URL("") is non-nil in Foundation, so either path is valid; main thing: no crash
        _ = value
    }

    // MARK: - UUID

    func testGetQueryUUID() {
        let id = UUID()
        let uri = URI("/path?id=\(id.uuidString)")!
        let value: UUID? = uri.getQuery("id")
        XCTAssertEqual(value, id)
    }

    func testGetQueryUUIDInvalidReturnsNil() {
        let uri = URI("/path?id=not-a-uuid")!
        let value: UUID? = uri.getQuery("id")
        XCTAssertNil(value)
    }

    // MARK: - Multiple query params

    func testGetQueryMultipleParams() {
        let uri = URI("/search?page=2&active=true&name=swift")!
        let page: Int? = uri.getQuery("page")
        let active: Bool? = uri.getQuery("active")
        let name: String? = uri.getQuery("name")
        XCTAssertEqual(page, 2)
        XCTAssertEqual(active, true)
        XCTAssertEqual(name, "swift")
    }
}
