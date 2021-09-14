/// Represents an HTTP version.
public struct Version: Encodable, Equatable {
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
    public enum Major: Int {
        /// The first major HTTP version.
        case one = 1

        /// The second major HTTP version.
        case two
    }
}

extension Version: CustomStringConvertible {
    /// See `CustomStringConvertible`.
    public var description: String { "HTTP/\(major).\(minor)" }
}
