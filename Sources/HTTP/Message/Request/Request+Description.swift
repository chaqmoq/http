extension Request {
    public var description: String {
        var description = ""
        for (name, value) in headers { description.append("\(name): \(value)\n") }
        description.append("\n\(body)")

        return "\(method) \(uri) \(version)\n\(description)"
    }
}
