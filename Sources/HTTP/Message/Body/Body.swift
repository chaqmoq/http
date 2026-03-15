import Foundation
import NIO

/// The payload of an HTTP request or response.
///
/// `Body` stores its content in a NIO `ByteBuffer` — a reference-counted, pooled
/// byte store. This means:
/// - No heap re-allocation on appends when capacity allows (copy-on-write).
/// - The NIO pipeline can pass the buffer straight through to the network write
///   without copying it through `[UInt8]` first.
/// - Only the computed properties that materialise a specific type (`bytes`, `data`)
///   copy bytes out of the buffer.
///
/// ```swift
/// let body = Body(string: "Hello, World!")
/// print(body.string) // "Hello, World!"
/// print(body.count)  // 13
/// ```
public struct Body: Sendable {
    // Internal ByteBuffer. Exposed as `internal` so same-module NIO handlers
    // (ResponseEncoder, RequestDecoder) can read/write it without going through
    // the public [UInt8]-copying accessors.
    var _buffer: ByteBuffer

    // MARK: - Public views

    /// The raw byte representation of the body content.
    ///
    /// Copies bytes out of the internal `ByteBuffer`. Prefer ``buffer`` in NIO
    /// channel handlers to avoid the extra allocation.
    public var bytes: [UInt8] {
        _buffer.getBytes(at: _buffer.readerIndex, length: _buffer.readableBytes) ?? []
    }

    /// The body content as `Foundation.Data`.
    public var data: Data { Data(bytes) }

    /// The body content decoded as a UTF-8 string. Returns an empty string on failure.
    ///
    /// Uses `String(bytes:encoding:)` rather than NIO's `ByteBuffer.getString`, which
    /// substitutes Unicode replacement characters (U+FFFD) for invalid UTF-8 sequences
    /// instead of returning `nil`. This property returns `""` for invalid UTF-8.
    public var string: String {
        String(bytes: bytes, encoding: .utf8) ?? ""
    }

    /// The number of bytes in the body.
    public var count: Int { _buffer.readableBytes }

    /// `true` when the body contains no bytes.
    public var isEmpty: Bool { _buffer.readableBytes == 0 }

    /// The underlying NIO `ByteBuffer`.
    ///
    /// Use this in NIO channel handlers to write the body directly to the network
    /// without copying through `[UInt8]` or `Data` first.
    public var buffer: ByteBuffer { _buffer }

    // MARK: - Initializers

    /// Creates an empty body or one initialised from a raw byte array.
    ///
    /// - Parameter bytes: The raw bytes for the body. Defaults to an empty array.
    public init(bytes: [UInt8] = []) {
        var buf = ByteBufferAllocator().buffer(capacity: bytes.count)
        buf.writeBytes(bytes)
        _buffer = buf
    }

    /// Creates a body from `Foundation.Data`.
    ///
    /// - Parameter data: The data to use as the body content.
    public init(data: Data) {
        var buf = ByteBufferAllocator().buffer(capacity: data.count)
        buf.writeBytes(data)
        _buffer = buf
    }

    /// Creates a body from a UTF-8 encoded string.
    ///
    /// - Parameter string: The string to encode as the body content.
    public init(string: String) {
        var buf = ByteBufferAllocator().buffer(capacity: string.utf8.count)
        buf.writeString(string)
        _buffer = buf
    }

    /// Creates a body directly from a NIO `ByteBuffer` without copying.
    ///
    /// Use this initialiser in NIO channel handlers where the buffer is already
    /// allocated from the channel's pool — avoids an extra heap allocation.
    ///
    /// - Parameter buffer: The NIO `ByteBuffer` to adopt as the body storage.
    public init(_ buffer: ByteBuffer) {
        _buffer = buffer
    }
}

// MARK: - Mutation

extension Body {
    /// Appends raw bytes to the body.
    public mutating func append(bytes: [UInt8]) {
        _buffer.writeBytes(bytes)
    }

    /// Appends `Foundation.Data` to the body.
    public mutating func append(data: Data) {
        _buffer.writeBytes(data)
    }

    /// Appends a UTF-8 encoded string to the body.
    public mutating func append(string: String) {
        _buffer.writeString(string)
    }
}

// MARK: - Encodable

extension Body: Encodable {
    /// Encodes the body as a UTF-8 string in a single-value container.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

// MARK: - Equatable

extension Body: Equatable {
    /// Returns `true` when both bodies contain identical byte sequences.
    public static func == (lhs: Body, rhs: Body) -> Bool {
        lhs._buffer.readableBytesView.elementsEqual(rhs._buffer.readableBytesView)
    }
}

// MARK: - Decode helpers

extension Body {
    /// Decodes the body as a JSON-encoded value of type `T`.
    ///
    /// ```swift
    /// server.onReceive = { request in
    ///     let login = try request.body.decode(LoginRequest.self)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - type: The `Decodable` type to decode into. Can be inferred from context.
    ///   - decoder: The JSON decoder to use. Defaults to a standard `JSONDecoder`.
    /// - Throws: `DecodingError` if the body is not valid JSON or does not match `T`.
    public func decode<T: Decodable>(_ type: T.Type = T.self, using decoder: JSONDecoder = .init()) throws -> T {
        try decoder.decode(type, from: data)
    }
}

// MARK: - CustomStringConvertible

extension Body: CustomStringConvertible {
    /// A UTF-8 string representation of the body content, suitable for debugging.
    public var description: String { string }
}

// MARK: - File

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
