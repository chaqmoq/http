/// Represents a single HTTP header field consisting of a name and a value.
public struct Header: Encodable, Sendable {
    /// The header field name, stored in lowercase (e.g. `"content-type"`).
    ///
    /// Immutable after creation — the lowercase normalisation applied at init
    /// is an invariant that ``Headers`` lookup relies on.
    public let name: String

    /// The header field value (e.g. `"application/json"`).
    ///
    /// CR, LF, and NUL characters are stripped on assignment to prevent HTTP response
    /// splitting / header injection when untrusted data is placed in a header (or in a
    /// `Set-Cookie` value, which is serialised through this type). This is the single
    /// chokepoint every outbound header passes through before reaching the encoder.
    public var value: String {
        didSet { value = Header.sanitized(value) }
    }

    /// Initializes a new header with a raw string name.
    ///
    /// - Parameters:
    ///   - name: The header field name.
    ///   - value: The header field value.
    public init(name: String, value: String) {
        // didSet does not fire during initialisation, so sanitise explicitly here.
        self.name = Header.sanitized(name.lowercased())
        self.value = Header.sanitized(value)
    }

    /// Initializes a new header using a well-known ``HeaderName`` constant.
    ///
    /// - Parameters:
    ///   - name: A ``HeaderName`` case whose `rawValue` is used as the field name.
    ///   - value: The header field value.
    public init(name: HeaderName, value: String) {
        // The HeaderName rawValue is a trusted constant and needs no sanitisation.
        self.name = name.rawValue
        self.value = Header.sanitized(value)
    }

    /// Removes CR (`\r`), LF (`\n`), and NUL (`\0`) — the characters that allow a
    /// header value to be broken into additional header lines or terminate the value
    /// early. Returns the input unchanged (no allocation) when it contains none of them.
    static func sanitized(_ string: String) -> String {
        guard string.utf8.contains(where: { $0 == 0x0D || $0 == 0x0A || $0 == 0x00 }) else {
            return string
        }

        return String(String.UnicodeScalarView(
            string.unicodeScalars.filter { $0 != "\r" && $0 != "\n" && $0 != "\0" }
        ))
    }
}
