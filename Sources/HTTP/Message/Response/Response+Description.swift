extension Response {
    public var description: String {
        var content = ""

        for header in headers {
            content.append("\(header.name): \(header.value)\n")
        }

        content.append("\n\(body)")

        return "\(version) \(status)\n\(content)"
    }
}
