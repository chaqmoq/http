/// Represents a single HTTP header field consisting of a name and a value.
public struct Header: Encodable, Sendable {
    /// The header field name, stored in lowercase (e.g. `"content-type"`).
    ///
    /// Immutable after creation — the lowercase normalisation applied at init
    /// is an invariant that ``Headers`` lookup relies on.
    public let name: String

    /// The header field value (e.g. `"application/json"`).
    public var value: String

    /// Initializes a new header with a raw string name.
    ///
    /// - Parameters:
    ///   - name: The header field name.
    ///   - value: The header field value.
    public init(name: String, value: String) {
        self.name = name.lowercased()
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
