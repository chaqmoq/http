/// An HTTP `Request` or `Response` message.
public protocol Message: CustomStringConvertible {
    /// An HTTP version.
    var version: Version { get set }

    /// HTTP headers.
    var headers: Headers { get set }

    /// HTTP cookies.
    var cookies: Set<Cookie> { get }

    /// An HTTP body.
    var body: Body { get set }
}

extension Message {
    mutating func setContentLengthHeader() {
        headers.set(.init(name: .contentLength, value: String(body.count)))
    }
}
