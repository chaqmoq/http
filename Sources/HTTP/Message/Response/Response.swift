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
    mutating func setCookies() {
        mutableCookies.removeAll()
        let values = headers.values(for: .setCookie)
        guard !values.isEmpty else { return }

        for value in values {
            var components = value.components(separatedBy: ";").filter { $0 != "" }

            if let component = components.first {
                components.removeFirst()
                let subComponents = component.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")

                if let name = subComponents.first, let value = subComponents.last, subComponents.count == 2 {
                    var cookie = Cookie(name: name, value: value)
                    var cookieExists = false

                    if let index = mutableCookies.firstIndex(of: cookie) {
                        cookie = mutableCookies[index]
                        cookieExists = true
                    }

                    for component in components {
                        let subComponents = component.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")

                        if let key = subComponents.first, let optionKey = Cookie.OptionKey(rawValue: key) {
                            let count = subComponents.count

                            switch optionKey {
                            case .expires:
                                if let value = subComponents.last, count == 2 { cookie.expires = Date(rfc1123: value) }
                            case .maxAge:
                                if let value = subComponents.last, count == 2 { cookie.maxAge = Int(value) }
                            case .domain:
                                if let value = subComponents.last, count == 2 { cookie.domain = value }
                            case .path:
                                if let value = subComponents.last, count == 2 { cookie.path = value }
                            case .isSecure:
                                cookie.isSecure = true
                            case .isHTTPOnly:
                                cookie.isHTTPOnly = true
                            case .sameSite:
                                if let value = subComponents.last, let optionValue = Cookie.SameSite(rawValue: value) {
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
}
