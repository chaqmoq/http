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
    public func hasCookie(named name: String) -> Bool {
        cookies.contains(where: { $0.name == name })
    }

    public mutating func setCookie(_ cookie: Cookie) {
        var headerLine = headers.value(for: .cookie) ?? ""

        if headerLine.isEmpty {
            headerLine = "\(cookie.name)=\(cookie.value)"
        } else {
            HeaderUtil.setParameterValue(cookie.value, named: cookie.name, in: &headerLine)
        }

        headers.set(headerLine, for: .cookie)
    }

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

    public mutating func clearCookie(named name: String) {
        guard var headerLine = headers.value(for: .cookie) else { return }
        HeaderUtil.removeParameter(named: name, in: &headerLine)

        if headerLine.isEmpty {
            headers.remove(.cookie)
        } else {
            headers.set(headerLine, for: .cookie)
        }
    }

    public mutating func clearCookies() {
        headers.remove(.cookie)
    }
}
