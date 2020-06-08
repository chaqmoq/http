public struct HeaderBag {
    public typealias ArrayOfTuplesType = [(String, String)]
    private var headers: ArrayOfTuplesType

    public init() {
        headers = .init()
    }

    public func indices(for key: String) -> [Int] {
        let key = key.lowercased()
        return headers.enumerated().filter({ $0.element.0 == key }).map { $0.offset }
    }

    public mutating func add(value: String, for key: String) {
        let key = key.lowercased()
        headers.append((key, value))
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

    public mutating func remove(for key: String) {
        let key = key.lowercased()
        let indices = self.indices(for: key)

        for index in indices {
            headers.remove(at: index)
        }
    }

    public func has(key: String) -> Bool {
        let key = key.lowercased()
        return headers.contains(where: { $0.0 == key })
    }

    public func values(for key: String) -> [String] {
        let key = key.lowercased()
        return headers.filter({ $0.0 == key }).map { $0.1 }
    }

    public func value(for key: String) -> String? {
        let key = key.lowercased()
        return values(for: key).last
    }
}

extension HeaderBag: Collection {
    public typealias Index = ArrayOfTuplesType.Index
    public typealias Element = ArrayOfTuplesType.Element

    public var startIndex: Index { headers.startIndex }
    public var endIndex: Index { headers.endIndex }

    public subscript(index: Index) -> Element { headers[index] }
    public func index(after index: Index) -> Index { headers.index(after: index) }
}

extension HeaderBag: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = String

    public init(dictionaryLiteral elements: (String, String)...) {
        headers = elements.map { ($0.0.lowercased(), $0.1) }
    }
}
