public struct Request: Message {
    public var method: Method
    public var uri: URI
    public var version: Version
    public var headers: Headers { didSet { setCookies() } }
    public var cookies: Set<Cookie> { mutableCookies }
    private var mutableCookies: Set<Cookie>
    public var body: Body { didSet { setContentLengthHeader() }}

    public init(
        method: Method = .GET,
        uri: URI = .default,
        version: Version = .init(),
        headers: Headers = .init(),
        body: Body = .init()
    ) {
        self.method = method
        self.uri = uri
        self.version = version
        self.headers = headers
        mutableCookies = .init()
        self.body = body

        setContentLengthHeader()
        setCookies()
    }
}

extension Request {
    mutating func setCookies() {
        mutableCookies.removeAll()
        guard let headerLine = headers.value(for: .cookie) else { return }
        let parameters = headerLine.components(separatedBy: ";").filter { $0 != "" }

        for parameter in parameters {
            let nameValue = parameter.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")

            if let name = nameValue.first, let value = nameValue.last, nameValue.count == 2 {
                let cookie = Cookie(name: name, value: value)
                mutableCookies.insert(cookie)
            }
        }
    }
}
