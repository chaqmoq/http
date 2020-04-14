public struct Response: Message {
    public var version: Version
    public var status: Status
    public var headers: ParameterBag<String, String>
    public var body: Body { didSet { setContentLengthHeader() } }

    public init(
        version: Version = .init(),
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
