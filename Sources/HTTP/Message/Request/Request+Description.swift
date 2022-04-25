extension Request {
    public var description: String {
        var content = ""

        for header in headers {
            content.append("\(header.name): \(header.value)\n")
        }

        content.append("\n\(body)")

        return "\(method) \(uri) \(version)\n\(content)"
    }
}
