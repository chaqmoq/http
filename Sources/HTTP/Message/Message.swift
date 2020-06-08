public protocol Message: CustomStringConvertible {
    var version: Version { get set }
    var headers: HeaderBag { get set }
    var body: Body { get set }
}

extension Message {
    mutating func setContentLengthHeader() {
        headers.set(value: String(body.count), for: Header.contentLength.rawValue)
    }
}
