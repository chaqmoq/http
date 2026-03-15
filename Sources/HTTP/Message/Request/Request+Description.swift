extension Request: CustomStringConvertible {
    /// A human-readable representation of the HTTP request for debugging.
    ///
    /// The format mirrors a raw HTTP message:
    /// ```
    /// GET /path HTTP/1.1
    /// Content-Type: application/json
    ///
    /// {"key":"value"}
    /// ```
    public var description: String {
        var content = ""

        for header in headers {
            content.append("\(header.name): \(header.value)\n")
        }

        content.append("\n\(body)")

        return "\(method) \(uri) \(version)\n\(content)"
    }
}
