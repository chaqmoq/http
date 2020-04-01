public protocol Message: CustomStringConvertible {
    var version: ProtocolVersion { get set }
    var headers: ParameterBag<Header, String> { get set }
    var body: Body { get set }
}
