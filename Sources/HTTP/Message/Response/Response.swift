public struct Response: Message {
    public var version: Version
    public var status: Status
    public var headers: ParameterBag<String, String>
    public var body: Body { didSet { setContentLengthHeader() } }

    public init(
        body: Body = .init(),
        status: Status = .ok,
        headers: ParameterBag<String, String> = .init(),
        version: Version = .init()
    ) {
        self.version = version
        self.status = status
        self.headers = headers
        self.body = body

        setContentLengthHeader()
    }
}
