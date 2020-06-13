public protocol Message: CustomStringConvertible {
    var version: Version { get set }
    var headers: Headers { get set }
    var cookies: Set<Cookie> { get }
    var body: Body { get set }
}

extension Message {
    mutating func setContentLengthHeader() {
        headers.set(String(body.count), for: .contentLength)
    }
}
