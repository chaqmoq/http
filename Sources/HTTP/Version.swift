/// Represents an HTTP version.
public struct Version: Encodable, Equatable, Sendable {
    /// A major HTTP version.
    public var major: Int

    /// A minor HTTP version.
    public var minor: Int

    /// Initializes a new instance with major and minor versions.
    ///
    /// - Parameters:
    ///   - major: A major HTTP version. Defaults to `1`.
    ///   - minor: A minor HTTP version. Defaults to `1`.
    public init(major: Int = 1, minor: Int = 1) {
        self.major = major
        self.minor = minor
    }
}

extension Version {
    /// Represents a major HTTP version.
    public enum Major: Int, Sendable {
        /// The first major HTTP version.
        case one = 1

        /// The second major HTTP version.
        case two
    }
}

extension Version: CustomStringConvertible {
    /// A human-readable HTTP version string, e.g. `"HTTP/1.1"` or `"HTTP/2.0"`.
    ///
    /// The format follows the standard HTTP version token used in request/status lines.
    public var description: String { "HTTP/\(major).\(minor)" }
}
