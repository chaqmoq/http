/// A type-erased `Encodable` wrapper that can hold any value.
///
/// Used to store heterogeneous values in request attribute and parameter
/// dictionaries while preserving `Encodable` conformance for the container.
///
/// ```swift
/// let box = AnyEncodable("hello")
/// let recovered = box.value as? String // "hello"
/// ```
public struct AnyEncodable: Encodable, Equatable, ExpressibleByStringLiteral,
    ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByBooleanLiteral,
    ExpressibleByNilLiteral {
    /// The wrapped value. May be `nil`.
    public let value: Any?

    public init(_ value: Any?) {
        self.value = value
    }

    // MARK: - Literal initialisers

    public init(stringLiteral value: String) { self.init(value) }
    public init(integerLiteral value: Int) { self.init(value) }
    public init(floatLiteral value: Double) { self.init(value) }
    public init(booleanLiteral value: Bool) { self.init(value) }
    public init(nilLiteral: ()) { self.init(nil) }

    // MARK: - Equatable

    public static func == (lhs: AnyEncodable, rhs: AnyEncodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (nil, nil): return true
        case (let l?, let r?):
            if let lh = l as? AnyHashable, let rh = r as? AnyHashable { return lh == rh }
            return false
        default: return false
        }
    }

    // MARK: - Encodable

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case nil: try container.encodeNil()
        case let value as Bool: try container.encode(value)
        case let value as Int: try container.encode(value)
        case let value as Int8: try container.encode(value)
        case let value as Int16: try container.encode(value)
        case let value as Int32: try container.encode(value)
        case let value as Int64: try container.encode(value)
        case let value as UInt: try container.encode(value)
        case let value as UInt8: try container.encode(value)
        case let value as UInt16: try container.encode(value)
        case let value as UInt32: try container.encode(value)
        case let value as UInt64: try container.encode(value)
        case let value as Float: try container.encode(value)
        case let value as Double: try container.encode(value)
        case let value as String: try container.encode(value)
        case let value as [String: AnyEncodable]: try container.encode(value)
        case let value as [AnyEncodable]: try container.encode(value)
        case let value as Encodable: try value.encode(to: encoder)
        default:
            let context = EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "AnyEncodable cannot encode value of type \(type(of: value!))"
            )
            throw EncodingError.invalidValue(value!, context)
        }
    }
}
