public struct Response: Message {
    public var version: ProtocolVersion
    public var status: Status
    public var headers: ParameterBag<String, String>
    public var body: Body { didSet { setContentLengthHeader() } }

    public init(
        version: ProtocolVersion = .init(),
        status: Status = .ok,
        headers: ParameterBag<String, String> = .init(),
        body: Body = .init()
    ) {
        self.version = version
        self.status = status
        self.headers = headers
        self.body = body

        setContentLengthHeader()
    }
}
