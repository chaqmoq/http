public struct Headers {
    public typealias ArrayType = [Header]
    private var headers: ArrayType

    public init() {
        headers = .init()
    }

    public init(_ headers: [HeaderName: String]) {
        self.headers = headers.map { ($0.0.rawValue.lowercased(), $0.1) }
    }

    public init(_ headers: (HeaderName, String)...) {
        self.headers = headers.map { ($0.0.rawValue.lowercased(), $0.1) }
    }

    public func indices(for name: String) -> [Int] {
        let name = name.lowercased()
        return headers.enumerated().filter({ $0.element.0 == name }).map { $0.offset }
    }

    public func indices(for name: HeaderName) -> [Int] {
        indices(for: name.rawValue)
    }

    public mutating func add(_ value: String, for name: String) {
        let name = name.lowercased()
        headers.append((name, value))
    }

    public mutating func add(_ value: String, for name: HeaderName) {
        add(value, for: name.rawValue)
    }

    public mutating func set(_ value: String, for name: String) {
        let name = name.lowercased()
        let indices = self.indices(for: name)

        if indices.isEmpty {
            headers.append((name, value))
        } else {
            for index in indices {
                headers[index] = (name, value)
            }
        }
    }

    public mutating func set(_ value: String, for name: HeaderName) {
        set(value, for: name.rawValue)
    }

    public mutating func remove(_ name: String) {
        let name = name.lowercased()
        let indices = self.indices(for: name)

        for index in indices {
            headers.remove(at: index)
        }
    }

    public mutating func remove(_ name: HeaderName) {
        remove(name.rawValue)
    }

    public func has(_ name: String) -> Bool {
        let name = name.lowercased()
        return headers.contains(where: { $0.0 == name })
    }

    public func has(_ name: HeaderName) -> Bool {
        has(name.rawValue)
    }

    public func values(for name: String) -> [String] {
        let name = name.lowercased()
        return headers.filter({ $0.0 == name }).map { $0.1 }
    }

    public func values(for name: HeaderName) -> [String] {
        values(for: name.rawValue)
    }

    public func value(for name: String) -> String? {
        let name = name.lowercased()
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

    public subscript(index: Index) -> Element { headers[index] }
    public func index(after index: Index) -> Index { headers.index(after: index) }
}

extension Headers: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = String

    public init(dictionaryLiteral headers: Header...) {
        self.headers = headers.map { ($0.0.lowercased(), $0.1) }
    }
}
