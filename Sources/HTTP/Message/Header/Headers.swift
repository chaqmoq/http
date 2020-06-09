public struct Headers {
    public typealias ArrayType = [Header]
    private var headers: ArrayType

    public init() {
        headers = .init()
    }

    public func indices(for key: String) -> [Int] {
        let key = key.lowercased()
        return headers.enumerated().filter({ $0.element.0 == key }).map { $0.offset }
    }

    public func indices(for key: HeaderName) -> [Int] {
        indices(for: key.rawValue)
    }

    public mutating func add(value: String, for key: String) {
        let key = key.lowercased()
        headers.append((key, value))
    }

    public mutating func add(value: String, for key: HeaderName) {
        add(value: value, for: key.rawValue)
    }

    public mutating func set(value: String, for key: String) {
        let key = key.lowercased()
        let indices = self.indices(for: key)

        if indices.isEmpty {
            headers.append((key, value))
        } else {
            for index in indices {
                headers[index] = (key, value)
            }
        }
    }

    public mutating func set(value: String, for key: HeaderName) {
        set(value: value, for: key.rawValue)
    }

    public mutating func remove(for key: String) {
        let key = key.lowercased()
        let indices = self.indices(for: key)

        for index in indices {
            headers.remove(at: index)
        }
    }

    public mutating func remove(for key: HeaderName) {
        remove(for: key.rawValue)
    }

    public func has(key: String) -> Bool {
        let key = key.lowercased()
        return headers.contains(where: { $0.0 == key })
    }

    public func has(key: HeaderName) -> Bool {
        has(key: key.rawValue)
    }

    public func values(for key: String) -> [String] {
        let key = key.lowercased()
        return headers.filter({ $0.0 == key }).map { $0.1 }
    }

    public func values(for key: HeaderName) -> [String] {
        values(for: key.rawValue)
    }

    public func value(for key: String) -> String? {
        let key = key.lowercased()
        return values(for: key).last
    }

    public func value(for key: HeaderName) -> String? {
        value(for: key.rawValue)
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

    public init(dictionaryLiteral elements: Header...) {
        headers = elements.map { ($0.0.lowercased(), $0.1) }
    }
}
