import Foundation

extension Body {
    /// Attempts to decode the body as a JSON object.
    ///
    /// Returns an empty dictionary when the body is empty or does not contain valid JSON.
    public var json: [String: Any] {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? .init()
    }

    /// Decodes an `application/x-www-form-urlencoded` body into a parameter dictionary.
    ///
    /// `+` characters are interpreted as spaces and percent-encoded sequences are decoded
    /// before parsing. Returns an empty dictionary when the body is empty.
    public var urlEncoded: [String: AnyEncodable] {
        var parameters = [String: AnyEncodable]()

        if let string = string.removingPercentEncoding?.replacingOccurrences(of: "+", with: " ") {
            var urlComponents = URLComponents()
            urlComponents.query = string

            if let queryItems = urlComponents.queryItems, !queryItems.isEmpty {
                for queryItem in queryItems {
                    parameters[queryItem.name] = AnyEncodable(queryItem.value)
                }
            }
        }

        return parameters
    }

    /// Parses a `multipart/form-data` body using the given boundary string.
    ///
    /// Works directly against the internal `ByteBuffer` — no full-body copy to `[UInt8]`
    /// is made. Header strings and field values are extracted as targeted sub-reads;
    /// file data is sliced from the buffer and copied to `Data` only for the portion
    /// that belongs to that file.
    ///
    /// Returns a tuple of:
    /// - `parameters`: plain text fields keyed by their `name` attribute.
    /// - `files`: uploaded files keyed by their `name` attribute, each carrying
    ///   the original `filename` and raw `data`.
    ///
    /// Both collections are empty when the body is empty or the boundary is not found.
    ///
    /// - Parameter boundary: The boundary token from the `Content-Type` header
    ///   (without the leading `--`).
    public func multipart(boundary: String) -> ([String: AnyEncodable], [String: File]) {
        var parameters = [String: AnyEncodable]()
        var files = [String: File]()
        guard !isEmpty else { return (parameters, files) }

        let boundary = "--" + boundary
        let boundaryBytes = [UInt8](boundary.utf8)
        let boundaryLength = boundaryBytes.count
        var boundaryCounter = 0
        let carriageReturn: UInt8 = 13
        let newLine: UInt8 = 10
        var contentRanges = [Int]()

        // Work directly against the ByteBuffer using absolute indices.
        // This avoids materialising the entire body as a [UInt8] array.
        let base = _buffer.readerIndex
        let length = _buffer.readableBytes

        for i in 0..<length {
            guard let byte = _buffer.getInteger(at: base + i, as: UInt8.self) else { break }

            if byte == boundaryBytes[boundaryCounter] {
                boundaryCounter += 1
            } else {
                boundaryCounter = 0
            }

            if boundaryCounter == boundaryLength {
                let next1 = _buffer.getInteger(at: base + i + 1, as: UInt8.self)
                let next2 = _buffer.getInteger(at: base + i + 2, as: UInt8.self)

                let offset: Int
                if let n1 = next1, let n2 = next2, n1 == carriageReturn, n2 == newLine {
                    offset = 2
                } else {
                    offset = 1
                }

                if !contentRanges.isEmpty {
                    contentRanges.append(i - boundaryLength - offset)
                }

                contentRanges.append(i + 1 + offset)
                boundaryCounter = 0
            }
        }

        // Guard before removeLast(): a body with no boundary string at all leaves
        // contentRanges empty, and calling removeLast() on an empty array is a fatalError.
        guard !contentRanges.isEmpty else { return (parameters, files) }
        contentRanges.removeLast()
        guard !contentRanges.isEmpty else { return (parameters, files) }

        for index in stride(from: 1, through: contentRanges.count - 1, by: 2) {
            let headerStartIndex = contentRanges[index - 1]
            var headerEndIndex = headerStartIndex
            let valueEndIndex = contentRanges[index]
            var valueStartIndex = valueEndIndex

            for i in headerStartIndex...valueEndIndex {
                let b0 = _buffer.getInteger(at: base + i,     as: UInt8.self)
                let b1 = _buffer.getInteger(at: base + i + 1, as: UInt8.self)
                let b2 = _buffer.getInteger(at: base + i + 2, as: UInt8.self)
                let b3 = _buffer.getInteger(at: base + i + 3, as: UInt8.self)

                if let b0, let b1, let b2, let b3,
                   b0 == carriageReturn && b1 == newLine &&
                   b2 == carriageReturn && b3 == newLine
                {
                    headerEndIndex = i - 1
                    valueStartIndex = i + 4
                    break
                } else if let b0, let b1,
                          (b0 == newLine      && b1 == newLine) ||
                          (b0 == carriageReturn && b1 == carriageReturn)
                {
                    headerEndIndex = i - 1
                    valueStartIndex = i + 2
                    break
                }
            }

            if headerStartIndex < headerEndIndex {
                // Targeted read of just the header block — no full-body materialisation.
                let headerLength = headerEndIndex - headerStartIndex + 1
                if let headerLines = _buffer.getString(at: base + headerStartIndex, length: headerLength) {
                    if let name = HeaderUtil.getParameterValue(named: "name", in: headerLines) {
                        let valueLength = max(0, valueEndIndex - valueStartIndex + 1)

                        if let filename = HeaderUtil.getParameterValue(named: "filename", in: headerLines) {
                            // Slice the buffer for the file's bytes — only this portion
                            // is copied into Data, not the whole body.
                            let fileData = _buffer
                                .getSlice(at: base + valueStartIndex, length: valueLength)
                                .map { Data($0.readableBytesView) } ?? Data()
                            files[name] = File(filename: filename, data: fileData)
                        } else {
                            let value = _buffer.getString(at: base + valueStartIndex, length: valueLength)
                            parameters[name] = AnyEncodable(value)
                        }
                    }
                }
            }
        }

        return (parameters, files)
    }
}
