import Foundation

public struct Request: Message {
    public var method: Method
    public var uri: String { didSet { parseQuery() }}
    public var version: ProtocolVersion
    public var headers: ParameterBag<Header, String>
    public var body: Body { didSet { parseBody() }}
    public var pathParameters: ParameterBag<String, Any>?
    public var queryParameters: ParameterBag<String, Any>?
    public var bodyParameters: ParameterBag<String, Any>?
    public var files: ParameterBag<String, Data>?

    public init(
        method: Method = .GET,
        uri: String = "/",
        version: ProtocolVersion = .init(),
        headers: ParameterBag<Header, String> = .init(),
        body: Body = .init()
    ) {
        self.method = method
        self.uri = uri
        self.version = version
        self.headers = headers
        self.body = body

        parseQuery()
        parseBody()
    }
}
