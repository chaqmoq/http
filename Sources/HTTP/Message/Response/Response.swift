import struct Foundation.Data

public struct Response: Message {
    public var version: Version
    public var status: Status
    public var headers: ParameterBag<String, String>
    public var body: Body { didSet { setContentLengthHeader() } }

    public init(
        _ body: Body = .init(),
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

    public init(
        _ string: String,
        status: Status = .ok,
        headers: ParameterBag<String, String> = .init(),
        version: Version = .init()
    ) {
        self.init(.init(string: string), status: status, headers: headers, version: version)
    }

    public init(
        _ data: Data,
        status: Status = .ok,
        headers: ParameterBag<String, String> = .init(),
        version: Version = .init()
    ) {
        self.init(.init(data: data), status: status, headers: headers, version: version)
    }
}
