extension Request {
    public var description: String {
        var description = ""
        for header in headers { description.append("\(header.name): \(header.value)\n") }
        description.append("\n\(body)")

        return "\(method) \(uri) \(version)\n\(description)"
    }
}
