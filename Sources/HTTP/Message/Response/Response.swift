import struct Foundation.Data
import struct Foundation.Date

public struct Response: Message {
    public var version: Version
    public var status: Status
    public var headers: Headers { didSet { setCookies() } }
    public var cookies: Set<Cookie> { mutableCookies }
    private var mutableCookies: Set<Cookie>
    public var body: Body { didSet { setContentLengthHeader() } }

    public init(
        _ body: Body = .init(),
        status: Status = .ok,
        headers: Headers = .init(),
        version: Version = .init()
    ) {
        self.version = version
        self.status = status
        self.headers = headers
        mutableCookies = .init()
        self.body = body

        setContentLengthHeader()
        setCookies()
    }

    public init(
        _ string: String,
        status: Status = .ok,
        headers: Headers = .init(),
        version: Version = .init()
    ) {
        self.init(.init(string: string), status: status, headers: headers, version: version)
    }

    public init(
        _ data: Data,
        status: Status = .ok,
        headers: Headers = .init(),
        version: Version = .init()
    ) {
        self.init(.init(data: data), status: status, headers: headers, version: version)
    }
}

extension Response {
    public func hasCookie(named name: String) -> Bool {
        cookies.contains(where: { $0.name == name })
    }

    public mutating func setCookie(_ cookie: Cookie) {
        let headerName = HeaderName.setCookie.rawValue

        if let index = headers.firstIndex(where: { $0.0 == headerName && $0.1.hasPrefix(cookie.name) }) {
            headers[index] = (headerName, "\(cookie)")
        } else {
            headers.add("\(cookie)", for: .setCookie)
        }
    }

    mutating func setCookies() {
        mutableCookies.removeAll()
        let headerLines = headers.values(for: .setCookie)
        guard !headerLines.isEmpty else { return }

        for headerLine in headerLines {
            var parameters = headerLine.components(separatedBy: ";").filter { $0 != "" }

            if let firstParameter = parameters.first {
                parameters.removeFirst()
                let nameValue = firstParameter.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")

                if let name = nameValue.first, let value = nameValue.last, nameValue.count == 2 {
                    var cookie = Cookie(name: name, value: value)
                    var cookieExists = false

                    if let index = mutableCookies.firstIndex(of: cookie) {
                        cookie = mutableCookies[index]
                        cookieExists = true
                    }

                    for parameter in parameters {
                        let nameValue = parameter.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")

                        if let name = nameValue.first, let optionName = Cookie.OptionName(rawValue: name) {
                            let count = nameValue.count

                            switch optionName {
                            case .expires:
                                if let value = nameValue.last, count == 2 { cookie.expires = Date(rfc1123: value) }
                            case .maxAge:
                                if let value = nameValue.last, count == 2 { cookie.maxAge = Int(value) }
                            case .domain:
                                if let value = nameValue.last, count == 2 { cookie.domain = value }
                            case .path:
                                if let value = nameValue.last, count == 2 { cookie.path = value }
                            case .isSecure:
                                cookie.isSecure = true
                            case .isHTTPOnly:
                                cookie.isHTTPOnly = true
                            case .sameSite:
                                if let value = nameValue.last, let optionValue = Cookie.SameSite(rawValue: value) {
                                    cookie.sameSite = optionValue
                                }
                            }
                        }
                    }

                    if cookieExists {
                        mutableCookies.update(with: cookie)
                    } else {
                        mutableCookies.insert(cookie)
                    }
                }
            }
        }
    }

    public mutating func clearCookie(named name: String) {
        let headerName = HeaderName.setCookie.rawValue

        if let index = headers.firstIndex(where: { $0.0 == headerName && $0.1.hasPrefix(name) }) {
            headers.remove(at: index)
        }
    }

    public mutating func clearCookies() {
        headers.remove(.setCookie)
    }
}
