import AnyCodable
import Foundation
import NIO

/// Represents an inbound HTTP request received by the server.
///
/// `Request` is a value type that carries the complete state of an HTTP request,
/// including its method, URI, version, headers, cookies, body, locale, and any
/// parsed form parameters or uploaded files.
///
/// ```swift
/// server.onReceive = { request in
///     let name: String? = request.getParameter("name")
///     return Response("Hello, \(name ?? "World")!")
/// }
/// ```
public struct Request: Message, @unchecked Sendable {
    /// The event loop on which this request was received.
    public let eventLoop: EventLoop

    /// The HTTP method (verb) of the request.
    public var method: Method

    /// The request URI, including path and query parameters.
    public var uri: URI

    /// The HTTP version negotiated for this request.
    public var version: Version

    /// The HTTP headers carried by the request.
    ///
    /// Setting this property automatically re-parses cookies from the `Cookie` header.
    public var headers: Headers {
        didSet { setCookies() }
    }

    /// The request body.
    ///
    /// Setting this property automatically updates the `Content-Length` header and
    /// re-parses form parameters and uploaded files when a suitable `Content-Type` is present.
    public var body: Body {
        didSet {
            setContentLengthHeader()
            setParametersAndFiles()
        }
    }

    /// The locale derived from the `Accept-Language` header, or the system locale if absent.
    public var locale: Locale

    /// Arbitrary key/value attributes attached to the request by middleware.
    public var attributes: [String: AnyEncodable] { mutableAttributes }

    /// Cookies parsed from the `Cookie` request header.
    public var cookies: Set<Cookie> { mutableCookies }

    /// Files parsed from a `multipart/form-data` request body.
    public var files: [String: Body.File] { mutableFiles }

    /// Form parameters parsed from either `application/x-www-form-urlencoded` or
    /// `multipart/form-data` request bodies.
    public var parameters: [String: AnyEncodable] { mutableParameters }
    private var mutableAttributes = [String: AnyEncodable]()
    private var mutableCookies = Set<Cookie>()
    private var mutableFiles = [String: Body.File]()
    private var mutableParameters = [String: AnyEncodable]()

    public init(
        eventLoop: EventLoop,
        method: Method = .GET,
        uri: URI = .default,
        version: Version = .init(),
        headers: Headers = .init(),
        body: Body = .init(),
        locale: Locale? = nil
    ) {
        self.eventLoop = eventLoop
        self.method = method
        self.uri = uri
        self.version = version
        self.headers = headers
        self.body = body

        if let locale {
            self.locale = locale
        } else if let identifier = headers.get(.acceptLanguage), !identifier.isEmpty {
            self.locale = .init(identifier: identifier)
        } else {
            self.locale = .current
        }

        setContentLengthHeader()
        setParametersAndFiles()
        setCookies()
    }
}

extension Request {
    /// Attaches an arbitrary value to the request under the given key.
    ///
    /// Attributes are useful for passing data between middleware layers without modifying
    /// headers or the body.
    ///
    /// - Parameters:
    ///   - name: The attribute key.
    ///   - value: The value to store. Pass `nil` to store an explicit null.
    public mutating func setAttribute(_ name: String, value: Any?) {
        mutableAttributes[name] = AnyEncodable(value)
    }

    /// Returns the attribute value stored under `name`, cast to the inferred type.
    ///
    /// - Parameter name: The attribute key.
    /// - Returns: The stored value cast to `T`, or `nil` if absent or the cast fails.
    public func getAttribute<T>(_ name: String) -> T? {
        mutableAttributes[name]?.value as? T
    }
}

extension Request {
    /// Returns `true` if a cookie with the given name (case-insensitive) is present.
    ///
    /// - Parameter name: The cookie name to look up.
    public func hasCookie(named name: String) -> Bool {
        let name = name.lowercased()
        return cookies.contains(where: { $0.name.lowercased() == name })
    }

    /// Adds or updates a cookie in the `Cookie` request header.
    ///
    /// If a cookie with the same name already exists its value is replaced.
    ///
    /// - Parameter cookie: The cookie to set.
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

    /// Removes the cookie with the given name from the `Cookie` request header.
    ///
    /// Does nothing if no cookie with that name exists.
    ///
    /// - Parameter name: The name of the cookie to remove.
    public mutating func clearCookie(named name: String) {
        guard var value = headers.get(.cookie) else { return }
        HeaderUtil.removeParameter(named: name, in: &value)

        if value.isEmpty {
            headers.remove(.cookie)
        } else {
            headers.set(.init(name: .cookie, value: value))
        }
    }

    /// Removes all cookies from the `Cookie` request header.
    public mutating func clearCookies() {
        headers.remove(.cookie)
    }
}

extension Request {
    /// Returns a typed form or multipart parameter by name.
    ///
    /// Parameters are automatically parsed from `application/x-www-form-urlencoded` or
    /// `multipart/form-data` bodies. The following types are supported: `String`, `Int`,
    /// `Double`, `Bool`, `Float`, and all other numeric primitives.
    ///
    /// - Parameter name: The parameter key.
    /// - Returns: The parameter value cast to `T`, or `nil` if absent or the cast fails.
    public func getParameter<T>(_ name: String) -> T? {
        mutableParameters[name]?.value as? T
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
