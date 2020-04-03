extension Request {
    public var description: String {
        var description = ""

        for (header, value) in headers {
            description.append("\(header.rawValue): \(value)\n")
        }

        description.append("\n\(body)")

        return "\(method) \(uri) HTTP/\(version.major).\(version.minor)\n\(description)"
    }
}
