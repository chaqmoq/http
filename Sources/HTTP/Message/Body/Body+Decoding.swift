import AnyCodable
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
        var contentRanges: [Int] = []

        for (index, byte) in bytes.enumerated() {
            if byte == boundaryBytes[boundaryCounter] {
                boundaryCounter += 1
            } else {
                boundaryCounter = 0
            }

            if boundaryCounter == boundaryLength {
                let offset: Int

                // Guard against reading past the end of the buffer before peeking ahead.
                if index + 2 < bytes.count,
                   bytes[index + 1] == carriageReturn, bytes[index + 2] == newLine {
                    offset = 2
                } else {
                    offset = 1
                }

                if !contentRanges.isEmpty {
                    contentRanges.append(index - boundaryLength - offset)
                }

                contentRanges.append(index + 1 + offset)
                boundaryCounter = 0
            }
        }

        contentRanges.removeLast()
        guard !contentRanges.isEmpty else { return (parameters, files) }

        for index in stride(from: 1, through: contentRanges.count - 1, by: 2) {
            let headerStartIndex = contentRanges[index - 1]
            var headerEndIndex = headerStartIndex
            let valueEndIndex = contentRanges[index]
            var valueStartIndex = valueEndIndex

            for index in headerStartIndex ... valueEndIndex {
                if index + 3 < bytes.count,
                   bytes[index] == carriageReturn &&
                   bytes[index + 1] == newLine &&
                   bytes[index + 2] == carriageReturn &&
                   bytes[index + 3] == newLine
                {
                    headerEndIndex = index - 1
                    valueStartIndex = index + 4
                    break
                } else if index + 1 < bytes.count,
                          (bytes[index] == newLine && bytes[index + 1] == newLine) ||
                          (bytes[index] == carriageReturn && bytes[index + 1] == carriageReturn)
                {
                    headerEndIndex = index - 1
                    valueStartIndex = index + 2
                    break
                }
            }

            if headerStartIndex < headerEndIndex,
               let headerLines = String(bytes: bytes[headerStartIndex ... headerEndIndex], encoding: .utf8) {
                if let name = HeaderUtil.getParameterValue(named: "name", in: headerLines) {
                    if let filename = HeaderUtil.getParameterValue(named: "filename", in: headerLines) {
                        files[name] = File(filename: filename, data: Data(bytes[valueStartIndex ... valueEndIndex]))
                    } else {
                        parameters[name] = AnyEncodable(
                            String(bytes: bytes[valueStartIndex ... valueEndIndex], encoding: .utf8)
                        )
                    }
                }
            }
        }

        return (parameters, files)
    }
}
