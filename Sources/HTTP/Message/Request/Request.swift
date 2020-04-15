public struct Request: Message {
    public var method: Method
    public var uri: URI
    public var version: Version
    public var headers: ParameterBag<String, String>
    public var body: Body { didSet { setContentLengthHeader() }}

    public init(
        method: Method = .GET,
        uri: String = "/",
        version: Version = .init(),
        headers: ParameterBag<String, String> = .init(),
        body: Body = .init()
    ) {
        self.method = method
        self.uri = uri
        self.version = version
        self.headers = headers
        self.body = body

        setContentLengthHeader()
    }
}
