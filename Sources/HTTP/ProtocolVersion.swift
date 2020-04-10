public struct ProtocolVersion {
    public var major: Int
    public var minor: Int

    public init(major: Int = 1, minor: Int = 1) {
        self.major = major
        self.minor = minor
    }
}

extension ProtocolVersion {
    public enum Major: Int {
        case one = 1
        case two
    }
}

extension ProtocolVersion: Equatable {
    public static func == (lhs: ProtocolVersion, rhs: ProtocolVersion) -> Bool {
        return lhs.major == rhs.major && lhs.minor == rhs.minor
    }
}

extension ProtocolVersion: CustomStringConvertible {
    public var description: String { "HTTP/\(major).\(minor)" }
}
