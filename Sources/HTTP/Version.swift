public struct Version: Equatable {
    public var major: Int
    public var minor: Int

    public init(major: Int = 1, minor: Int = 1) {
        self.major = major
        self.minor = minor
    }
}

extension Version {
    public enum Major: Int {
        case one = 1
        case two
    }
}

extension Version: CustomStringConvertible {
    public var description: String { "HTTP/\(major).\(minor)" }
}
