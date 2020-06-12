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
        guard let components = headers.value(for: .cookie)?.components(separatedBy: "; ") else { return }

        for component in components {
            let subComponents = component.components(separatedBy: "=")

            if subComponents.count == 2, let name = subComponents.first, let value = subComponents.last {
                let cookie = Cookie(name: name, value: value)
                mutableCookies.insert(cookie)
            }
        }
    }
}
