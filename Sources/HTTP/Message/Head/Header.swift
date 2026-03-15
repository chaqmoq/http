/// Represents a single HTTP header field consisting of a name and a value.
public struct Header: Encodable, Sendable {
    /// The header field name (e.g. `"content-type"`).
    public var name: String

    /// The header field value (e.g. `"application/json"`).
    public var value: String

    /// Initializes a new header with a raw string name.
    ///
    /// - Parameters:
    ///   - name: The header field name.
    ///   - value: The header field value.
    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }

    /// Initializes a new header using a well-known ``HeaderName`` constant.
    ///
    /// - Parameters:
    ///   - name: A ``HeaderName`` case whose `rawValue` is used as the field name.
    ///   - value: The header field value.
    public init(name: HeaderName, value: String) {
        self.name = name.rawValue
        self.value = value
    }
}
