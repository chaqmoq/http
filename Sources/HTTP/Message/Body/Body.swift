import Foundation

/// The payload of an HTTP request or response.
///
/// `Body` stores its content as a raw byte buffer and exposes convenient views
/// (`bytes`, `data`, `string`) for different use-cases.
///
/// ```swift
/// let body = Body(string: "Hello, World!")
/// print(body.string) // "Hello, World!"
/// print(body.count)  // 13
/// ```
public struct Body: Encodable, Sendable {
    /// The raw byte representation of the body content.
    public var bytes: [UInt8] { content }

    /// The body content as `Foundation.Data`.
    public var data: Data { Data(content) }

    /// The body content decoded as a UTF-8 string. Returns an empty string on decoding failure.
    public var string: String { String(bytes: content, encoding: .utf8) ?? "" }

    /// The number of bytes in the body.
    public var count: Int { content.count }

    /// `true` when the body contains no bytes.
    public var isEmpty: Bool { content.isEmpty }

    private var content: [UInt8]

    /// Creates an empty body or one initialised from a raw byte array.
    ///
    /// - Parameter bytes: The raw bytes for the body. Defaults to an empty array.
    public init(bytes: [UInt8] = .init()) {
        content = bytes
    }

    /// Creates a body from `Foundation.Data`.
    ///
    /// - Parameter data: The data to use as the body content.
    public init(data: Data) {
        content = [UInt8](data)
    }

    /// Creates a body from a UTF-8 encoded string.
    ///
    /// - Parameter string: The string to encode as the body content.
    public init(string: String) {
        content = [UInt8](string.utf8)
    }
}

extension Body {
    /// Appends raw bytes to the body.
    ///
    /// - Parameter bytes: The bytes to append.
    public mutating func append(bytes: [UInt8]) {
        content.append(contentsOf: bytes)
    }

    /// Appends `Foundation.Data` to the body.
    ///
    /// - Parameter data: The data to append.
    public mutating func append(data: Data) {
        content.append(contentsOf: [UInt8](data))
    }

    /// Appends a UTF-8 encoded string to the body.
    ///
    /// - Parameter string: The string to append.
    public mutating func append(string: String) {
        content.append(contentsOf: [UInt8](string.utf8))
    }
}

extension Body: Equatable {
    /// Returns `true` when both bodies contain identical byte sequences.
    public static func == (lhs: Body, rhs: Body) -> Bool {
        lhs.bytes == rhs.bytes
    }
}

extension Body {
    /// Decodes the body as a JSON-encoded value of type `T`.
    ///
    /// This is the primary way to read a typed request body:
    ///
    /// ```swift
    /// struct LoginRequest: Decodable {
    ///     let email: String
    ///     let password: String
    /// }
    ///
    /// server.onReceive = { request in
    ///     let login = try request.body.decode(LoginRequest.self)
    ///     // ...
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - type: The `Decodable` type to decode into. Can be inferred from context.
    ///   - decoder: The JSON decoder to use. Defaults to a standard `JSONDecoder`.
    /// - Throws: `DecodingError` if the body is not valid JSON or does not match `T`.
    /// - Returns: An instance of `T` decoded from the body's JSON content.
    public func decode<T: Decodable>(_ type: T.Type = T.self, using decoder: JSONDecoder = .init()) throws -> T {
        try decoder.decode(type, from: data)
    }
}

extension Body: CustomStringConvertible {
    /// A UTF-8 string representation of the body content, suitable for debugging.
    ///
    /// Equivalent to ``string``. Returns an empty string when the content cannot be
    /// decoded as UTF-8.
    public var description: String { string }
}

extension Body {
    /// Represents a file uploaded as part of a `multipart/form-data` request.
    public struct File: Encodable, Sendable {
        /// The original filename provided by the client (e.g. `"avatar.png"`).
        public var filename: String

        /// The raw file content.
        public var data: Data

        /// Initializes a new `File`.
        ///
        /// - Parameters:
        ///   - filename: The original filename.
        ///   - data: The raw file content.
        public init(filename: String, data: Data) {
            self.filename = filename
            self.data = data
        }
    }
}
