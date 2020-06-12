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
        self.mutableCookies = .init()
        self.body = body

        setContentLengthHeader()
        setCookies()
    }
}

extension Request {
    mutating func setCookies() {
        guard let components = headers.value(for: .cookie)?.components(separatedBy: "; ") else { return }

        for component in components {
            let subComponents = component.components(separatedBy: "=")
            guard let name = subComponents.first, let value = subComponents.last else { continue }
            let cookie = Cookie(name: name, value: value)

            if mutableCookies.contains(cookie) {
                mutableCookies.update(with: cookie)
            } else {
                mutableCookies.insert(cookie)
            }
        }
    }
}
