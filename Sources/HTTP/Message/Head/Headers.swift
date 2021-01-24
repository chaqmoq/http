public struct Headers: Encodable {
    public typealias ArrayType = [Header]
    private var headers: ArrayType

    public init() {
        headers = .init()
    }

    public init(_ headers: [HeaderName: String]) {
        self.headers = headers.map { Header(name: $0.key, value: $0.value) }
    }

    public init(_ headers: (HeaderName, String)...) {
        self.headers = headers.map { Header(name: $0.0, value: $0.1) }
    }

    public init(_ headers: (String, String)...) {
        self.headers = headers.map { Header(name: $0.0, value: $0.1) }
    }

    public func indices(for name: String) -> [Int] {
        let name = name.lowercased()
        return headers.enumerated().filter({ $0.element.name.lowercased() == name }).map { $0.offset }
    }

    public func indices(for name: HeaderName) -> [Int] {
        indices(for: name.rawValue)
    }

    public mutating func add(_ value: String, for name: String) {
        headers.append(Header(name: name, value: value))
    }

    public mutating func add(_ value: String, for name: HeaderName) {
        add(value, for: name.rawValue)
    }

    public mutating func set(_ value: String, for name: String) {
        let indices = self.indices(for: name)

        if indices.isEmpty {
            headers.append(Header(name: name, value: value))
        } else {
            for index in indices {
                headers[index] = Header(name: name, value: value)
            }
        }
    }

    public mutating func set(_ value: String, for name: HeaderName) {
        set(value, for: name.rawValue)
    }

    public mutating func remove(_ name: String) {
        let indices = self.indices(for: name).reversed()

        for index in indices {
            headers.remove(at: index)
        }
    }

    public mutating func remove(_ name: HeaderName) {
        remove(name.rawValue)
    }

    public mutating func remove(at index: Int) {
        headers.remove(at: index)
    }

    public func has(_ name: String) -> Bool {
        let name = name.lowercased()
        return headers.contains(where: { $0.name.lowercased() == name })
    }

    public func has(_ name: HeaderName) -> Bool {
        has(name.rawValue)
    }

    public func values(for name: String) -> [String] {
        let name = name.lowercased()
        return headers.filter({ $0.name.lowercased() == name }).map { $0.value }
    }

    public func values(for name: HeaderName) -> [String] {
        values(for: name.rawValue)
    }

    public func value(for name: String) -> String? {
        return values(for: name).last
    }

    public func value(for name: HeaderName) -> String? {
        value(for: name.rawValue)
    }
}

extension Headers: Collection {
    public typealias Index = ArrayType.Index
    public typealias Element = ArrayType.Element

    public var startIndex: Index { headers.startIndex }
    public var endIndex: Index { headers.endIndex }

    public subscript(index: Index) -> Element {
        get { headers[index] }
        set { headers[index] = newValue }
    }

    public func index(after index: Index) -> Index {
        headers.index(after: index)
    }
}

extension Headers: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = String

    public init(dictionaryLiteral headers: (String, String)...) {
        self.headers = headers.map { Header(name: $0.0, value: $0.1) }
    }
}
