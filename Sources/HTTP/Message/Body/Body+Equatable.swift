extension Body: Equatable {
    public static func == (lhs: Body, rhs: Body) -> Bool { lhs.bytes == rhs.bytes }
}
