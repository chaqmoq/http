public struct Header: Encodable {
    public var name: String
    public var value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }

    public init(name: HeaderName, value: String) {
        self.name = name.rawValue
        self.value = value
    }
}
