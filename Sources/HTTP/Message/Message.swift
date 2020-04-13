public protocol Message: CustomStringConvertible {
    var version: ProtocolVersion { get set }
    var headers: ParameterBag<String, String> { get set }
    var body: Body { get set }
}

extension Message {
    mutating func setContentLengthHeader() {
        headers[Header.contentLength.rawValue] = String(body.count)
    }
}
