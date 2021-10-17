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

    public func get(_ name: String) -> String? {
        values(for: name).last
    }

    public func get(_ name: HeaderName) -> String? {
        get(name.rawValue)
    }

    public func has(_ name: String) -> Bool {
        headers.contains(where: { $0.name.lowercased() == name.lowercased() })
    }

    public func has(_ name: HeaderName) -> Bool {
        has(name.rawValue)
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

    func values(for name: String) -> [String] {
        headers.filter { $0.name.lowercased() == name.lowercased() }.map { $0.value }
    }

    func values(for name: HeaderName) -> [String] {
        values(for: name.rawValue)
    }

    func indices(for name: String) -> [Int] {
        headers.enumerated().filter { $0.element.name.lowercased() == name.lowercased() }.map { $0.offset }
    }

    func indices(for name: HeaderName) -> [Int] {
        indices(for: name.rawValue)
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
