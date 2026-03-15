extension Response: CustomStringConvertible {
    /// A human-readable representation of the HTTP response for debugging.
    ///
    /// The format mirrors a raw HTTP message:
    /// ```
    /// HTTP/1.1 200 OK
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

        return "\(version) \(status)\n\(content)"
    }
}
