/// An ordered, case-insensitive collection of HTTP header fields.
///
/// `Headers` stores fields in insertion order and supports multiple values for the same field
/// name (e.g. multiple `Set-Cookie` headers). All name comparisons are case-insensitive in
/// accordance with RFC 7230.
///
/// ```swift
/// var headers = Headers()
/// headers.add(.init(name: .contentType, value: "application/json"))
/// headers.set(.init(name: .accept, value: "text/html"))
/// let contentType = headers.get(.contentType) // "application/json"
/// ```
public struct Headers: Encodable, Sendable {
    public typealias ArrayType = [Header]
    private var headers: ArrayType

    /// Creates an empty `Headers` collection.
    public init() {
        headers = .init()
    }

    /// Creates a `Headers` collection from a dictionary of ``HeaderName`` to value pairs.
    ///
    /// - Parameter headers: A dictionary whose keys are ``HeaderName`` cases.
    public init(_ headers: [HeaderName: String]) {
        self.headers = headers.map { Header(name: $0.key, value: $0.value) }
    }

    /// Creates a `Headers` collection from variadic ``HeaderName``/value tuples.
    ///
    /// - Parameter headers: One or more `(HeaderName, String)` tuples.
    public init(_ headers: (HeaderName, String)...) {
        self.headers = headers.map { Header(name: $0.0, value: $0.1) }
    }

    /// Creates a `Headers` collection from variadic raw string name/value tuples.
    ///
    /// - Parameter headers: One or more `(String, String)` tuples.
    public init(_ headers: (String, String)...) {
        self.headers = headers.map { Header(name: $0.0, value: $0.1) }
    }

    /// Appends a header field, even if a field with the same name already exists.
    ///
    /// Use ``add(_:)`` when multiple values for the same field name are meaningful
    /// (e.g. `Set-Cookie`). For most headers you should use ``set(_:)`` instead.
    ///
    /// - Parameter header: The header to append.
    public mutating func add(_ header: Header) {
        headers.append(header)
    }

    /// Sets a header field, replacing all existing fields with the same name.
    ///
    /// If no existing field with the same name exists, the header is appended. If one or
    /// more fields already exist they are all replaced with the supplied value.
    ///
    /// - Parameter header: The header to set.
    public mutating func set(_ header: Header) {
        let indices = self.indices(for: header.name)

        if indices.isEmpty {
            headers.append(header)
        } else {
            for index in indices {
                headers[index] = header
            }
        }
    }

    /// Returns the last value for the given raw field name, or `nil` if not present.
    ///
    /// The lookup is case-insensitive. When multiple fields share the same name the last
    /// one wins (consistent with how browsers handle duplicate headers).
    ///
    /// - Parameter name: The header field name to look up.
    /// - Returns: The last matching field value, or `nil`.
    public func get(_ name: String) -> String? {
        values(for: name).last
    }

    /// Returns the last value for the given ``HeaderName``, or `nil` if not present.
    ///
    /// - Parameter name: A ``HeaderName`` case to look up.
    /// - Returns: The last matching field value, or `nil`.
    public func get(_ name: HeaderName) -> String? {
        get(name.rawValue)
    }

    /// Returns `true` when at least one field with the given raw name exists.
    ///
    /// - Parameter name: The header field name to check (case-insensitive).
    public func has(_ name: String) -> Bool {
        let lowercased = name.lowercased()
        return headers.contains(where: { $0.name == lowercased })
    }

    /// Returns `true` when at least one field with the given ``HeaderName`` exists.
    ///
    /// - Parameter name: A ``HeaderName`` case to check.
    public func has(_ name: HeaderName) -> Bool {
        has(name.rawValue)
    }

    /// Removes all fields whose name matches the given raw string.
    ///
    /// - Parameter name: The header field name to remove (case-insensitive).
    public mutating func remove(_ name: String) {
        let indices = self.indices(for: name).reversed()

        for index in indices {
            headers.remove(at: index)
        }
    }

    /// Removes all fields whose name matches the given ``HeaderName``.
    ///
    /// - Parameter name: A ``HeaderName`` case to remove.
    public mutating func remove(_ name: HeaderName) {
        remove(name.rawValue)
    }

    /// Removes the field at the given index.
    ///
    /// - Parameter index: The position of the field to remove.
    public mutating func remove(at index: Int) {
        headers.remove(at: index)
    }

    func values(for name: String) -> [String] {
        let lowercased = name.lowercased()
        return headers.filter { $0.name == lowercased }.map { $0.value }
    }

    func values(for name: HeaderName) -> [String] {
        values(for: name.rawValue)
    }

    func indices(for name: String) -> [Int] {
        let lowercased = name.lowercased()
        return headers.enumerated().filter { $0.element.name == lowercased }.map { $0.offset }
    }

    func indices(for name: HeaderName) -> [Int] {
        indices(for: name.rawValue)
    }
}

/// `Headers` conforms to `Collection` so that the full suite of sequence and collection
/// algorithms is available (e.g. `forEach`, `filter`, `first(where:)`, `enumerated()`).
extension Headers: Collection {
    public typealias Index = ArrayType.Index
    public typealias Element = ArrayType.Element

    /// The position of the first header, or `endIndex` when the collection is empty.
    public var startIndex: Index { headers.startIndex }

    /// The position one past the last header.
    public var endIndex: Index { headers.endIndex }

    /// Accesses the header at the given index.
    public subscript(index: Index) -> Element {
        get { headers[index] }
        set { headers[index] = newValue }
    }

    /// Returns the index immediately after `index`.
    public func index(after index: Index) -> Index {
        headers.index(after: index)
    }
}

/// Allows `Headers` to be initialised with a dictionary literal of raw `String` key/value
/// pairs, e.g. `let h: Headers = ["content-type": "application/json"]`.
extension Headers: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = String

    /// Creates a `Headers` collection from a dictionary literal.
    ///
    /// - Parameter headers: Variadic `(String, String)` key/value pairs.
    public init(dictionaryLiteral headers: (String, String)...) {
        self.headers = headers.map { Header(name: $0.0, value: $0.1) }
    }
}
