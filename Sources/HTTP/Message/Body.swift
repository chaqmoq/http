import Foundation

public struct Body {
    public var bytes: [UInt8] { content }
    public var data: Data? { string?.data(using: .utf8) }
    public var string: String? { String(bytes: content, encoding: .utf8) }
    public var isEmpty: Bool { content.isEmpty }
    private var content: [UInt8]

    public init(bytes: [UInt8] = .init()) {
        content = bytes
    }

    public init(data: Data) {
        content = [UInt8](data)
    }

    public init(string: String) {
        content = [UInt8](string.utf8)
    }
}

extension Body {
    public mutating func append(bytes: [UInt8]) {
        content.append(contentsOf: bytes)
    }
}

extension Body: CustomStringConvertible {
    public var description: String {
        return string ?? ""
    }
}
