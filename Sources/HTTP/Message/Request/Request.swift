import AnyCodable

public struct Request: Message {
    public var method: Method
    public var uri: URI
    public var version: Version
    public var headers: Headers { didSet { setCookies() } }
    public var body: Body {
        didSet {
            setContentLengthHeader()
            setParametersAndFiles()
        }
    }
    public var parameters: [String: AnyEncodable] { mutableParameters }
    public var files: [String: Body.File] { mutableFiles }
    public var cookies: Set<Cookie> { mutableCookies }
    private var mutableParameters: [String: AnyEncodable] = .init()
    private var mutableFiles: [String: Body.File] = .init()
    private var mutableCookies: Set<Cookie> = .init()

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
        self.body = body

        setContentLengthHeader()
        setParametersAndFiles()
        setCookies()
    }
}

extension Request {
    public func getParameter<T>(_ name: String) -> T? {
        parameters[name]?.value as? T
    }

    mutating func setParametersAndFiles() {
        guard let contentType = headers.get(.contentType) else { return }

        if contentType == "application/x-www-form-urlencoded" {
            mutableParameters = body.urlEncoded
        } else if contentType.hasPrefix("multipart/"),
                  let boundary = HeaderUtil.getParameterValue(named: "boundary", in: contentType) {
            (mutableParameters, mutableFiles) = body.multipart(boundary: boundary)
        }
    }
}

extension Request {
    public func hasCookie(named name: String) -> Bool {
        let name = name.lowercased()
        return cookies.contains(where: { $0.name.lowercased() == name })
    }

    public mutating func setCookie(_ cookie: Cookie) {
        var value = headers.get(.cookie) ?? ""
        HeaderUtil.setParameterValue(cookie.value, named: cookie.name, in: &value)
        headers.set(.init(name: .cookie, value: value))
    }

    mutating func setCookies() {
        mutableCookies.removeAll()
        guard let value = headers.get(.cookie) else { return }
        let parameters = value.components(separatedBy: ";").filter { $0 != "" }

        for parameter in parameters {
            let nameValue = parameter.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")

            if let name = nameValue.first, let value = nameValue.last, nameValue.count == 2 {
                let cookie = Cookie(name: name, value: value)
                mutableCookies.insert(cookie)
            }
        }
    }

    public mutating func clearCookie(named name: String) {
        guard var value = headers.get(.cookie) else { return }
        HeaderUtil.removeParameter(named: name, in: &value)

        if value.isEmpty {
            headers.remove(.cookie)
        } else {
            headers.set(.init(name: .cookie, value: value))
        }
    }

    public mutating func clearCookies() {
        headers.remove(.cookie)
    }
}
