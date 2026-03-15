@testable import HTTP
import NIO
import XCTest

final class BodyTests: XCTestCase {
    func testInitWithEmptyBytes() {
        // Act
        let body = Body()

        // Assert
        XCTAssertEqual(body.count, 0)
        XCTAssertTrue(body.isEmpty)
        XCTAssertTrue(body.string.isEmpty)
        XCTAssertTrue(body.data.isEmpty)
        XCTAssertTrue(body.bytes.isEmpty)
    }

    func testInitWithBytes() {
        // Arrange
        let string = "Hello World"
        let data = string.data(using: .utf8)!
        let bytes = [UInt8](data)

        // Act
        let body = Body(bytes: bytes)

        // Assert
        XCTAssertEqual(body.count, string.count)
        XCTAssertFalse(body.isEmpty)
        XCTAssertEqual(body.string, string)
        XCTAssertEqual(body.data, data)
        XCTAssertEqual(body.bytes, bytes)
    }

    func testInitWithEmptyData() {
        // Arrange
        let string = ""
        let data = string.data(using: .utf8)!
        let bytes = [UInt8](data)

        // Act
        let body = Body(data: data)

        // Assert
        XCTAssertEqual(body.count, string.count)
        XCTAssertTrue(body.isEmpty)
        XCTAssertEqual(body.string, string)
        XCTAssertEqual(body.data, data)
        XCTAssertEqual(body.bytes, bytes)
    }

    func testInitWithData() {
        // Arrange
        let string = "Hello World"
        let data = string.data(using: .utf8)!
        let bytes = [UInt8](data)

        // Act
        let body = Body(data: data)

        // Assert
        XCTAssertEqual(body.count, string.count)
        XCTAssertFalse(body.isEmpty)
        XCTAssertEqual(body.string, string)
        XCTAssertEqual(body.data, data)
        XCTAssertEqual(body.bytes, bytes)
    }

    func testInitWithEmptyString() {
        // Arrange
        let string = ""
        let data = string.data(using: .utf8)!
        let bytes = [UInt8](data)

        // Act
        let body = Body(string: string)

        // Assert
        XCTAssertEqual(body.count, string.count)
        XCTAssertTrue(body.isEmpty)
        XCTAssertEqual(body.string, string)
        XCTAssertEqual(body.data, data)
        XCTAssertEqual(body.bytes, bytes)
    }

    func testInitWithString() {
        // Arrange
        let string = "Hello World"
        let data = string.data(using: .utf8)!
        let bytes = [UInt8](data)

        // Act
        let body = Body(string: string)

        // Assert
        XCTAssertEqual(body.count, string.count)
        XCTAssertFalse(body.isEmpty)
        XCTAssertEqual(body.string, string)
        XCTAssertEqual(body.data, data)
        XCTAssertEqual(body.bytes, bytes)
    }

    func testAppendBytes() {
        // Arrange
        let string1 = "Hello"
        let string2 = " World"
        var body = Body(string: string1)

        // Act
        body.append(bytes: [UInt8](string2.data(using: .utf8)!))

        // Assert
        XCTAssertEqual(body.string, "\(string1)\(string2)")
    }

    func testAppendData() {
        // Arrange
        let string1 = "Hello"
        let string2 = " World"
        var body = Body(string: string1)

        // Act
        body.append(data: string2.data(using: .utf8)!)

        // Assert
        XCTAssertEqual(body.string, "\(string1)\(string2)")
    }

    func testAppendString() {
        // Arrange
        let string1 = "Hello"
        let string2 = " World"
        var body = Body(string: string1)

        // Act
        body.append(string: string2)

        // Assert
        XCTAssertEqual(body.string, "\(string1)\(string2)")
    }

    func testEquatable() {
        // Arrange
        let string = "Hello World"

        // Act
        let body1 = Body(string: string)
        let body2 = Body(string: string)

        // Assert
        XCTAssertEqual(body1, body2)
    }

    func testDescription() {
        // Arrange
        let string = "Hello World"
        let body = Body(string: string)

        // Assert
        XCTAssertEqual("\(body)", string)
    }

    /// Exercises the `?? ""` fallback in `Body.string` by storing bytes that are
    /// not valid UTF-8, making `String(bytes:encoding:)` return `nil`.
    func testStringReturnsFallbackForInvalidUTF8() {
        // 0xFF 0xFE are not valid UTF-8 sequences
        let body = Body(bytes: [0xFF, 0xFE, 0xFD])
        XCTAssertEqual(body.string, "")
    }

    // MARK: - ByteBuffer initializer and accessor

    func testInitWithByteBuffer() {
        // Arrange
        var buf = ByteBufferAllocator().buffer(capacity: 5)
        buf.writeString("Hello")

        // Act
        let body = Body(buf)

        // Assert
        XCTAssertEqual(body.count, 5)
        XCTAssertFalse(body.isEmpty)
        XCTAssertEqual(body.string, "Hello")
        XCTAssertEqual(body.bytes, [UInt8]("Hello".utf8))
    }

    func testBufferPropertyReturnsSameBytes() {
        // Arrange
        let string = "ByteBuffer round-trip"
        let body = Body(string: string)

        // Act
        let buf = body.buffer

        // Assert — buffer view must contain the same bytes as `bytes`
        XCTAssertEqual(
            Array(buf.readableBytesView),
            [UInt8](string.utf8)
        )
    }

    // MARK: - Typed JSON decoding

    func testDecodeJSON() throws {
        // Arrange
        struct Post: Decodable, Equatable {
            let title: String
            let views: Int
        }
        let body = Body(string: #"{"title":"Hello","views":7}"#)

        // Act
        let post = try body.decode(Post.self)

        // Assert
        XCTAssertEqual(post, Post(title: "Hello", views: 7))
    }

    // MARK: - Encodable conformance

    /// `Body.encode(to:)` stores the body as its UTF-8 string value inside a single-value
    /// container — so `JSONEncoder` wraps it in a JSON string literal.
    func testEncodeToJSONProducesUTF8StringValue() throws {
        let body = Body(string: "hello encoder")
        let data = try JSONEncoder().encode(body)
        let decoded = try JSONDecoder().decode(String.self, from: data)
        XCTAssertEqual(decoded, "hello encoder")
    }

    func testDecodeJSONInvalidThrows() {
        // Arrange
        let body = Body(string: "not json")

        // Act & Assert
        XCTAssertThrowsError(try body.decode([String: String].self))
    }

    func testJSON() {
        // Arrange
        let jsonString = "{\"title\": \"New post\", \"likesCount\": 100}"
        let body = Body(string: jsonString)

        // Act
        let parameters = body.json

        // Assert
        XCTAssertEqual(parameters.count, 2)
        XCTAssertEqual(parameters["title"] as? String, "New post")
        XCTAssertEqual(parameters["likesCount"] as? Int, 100)
    }

    func testURLEncoded() {
        // Arrange
        let urlEncodedString = "title=New+post&likesCount=100"
        let body = Body(string: urlEncodedString)

        // Act
        let parameters = body.urlEncoded

        // Assert
        XCTAssertEqual(parameters.count, 2)
        XCTAssertEqual(parameters["title"], "New post")
        XCTAssertEqual(parameters["likesCount"], "100")
    }
}
