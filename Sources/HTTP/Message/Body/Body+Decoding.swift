import Foundation

extension Body {
    public var json: [String: Any?] {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any?]) ?? .init()
    }

    public var urlEncoded: [String: String] {
        var parameters: [String: String] = .init()

        if let string = string.removingPercentEncoding?.replacingOccurrences(of: "+", with: " ") {
            var urlComponents = URLComponents()
            urlComponents.query = string

            if let queryItems = urlComponents.queryItems, !queryItems.isEmpty {
                for queryItem in queryItems {
                    parameters[queryItem.name] = queryItem.value
                }
            }
        }

        return parameters
    }

    public func multipart(boundary: String) -> ([String: String], [String: File]) {
        var parameters: [String: String] = .init()
        var files: [String: File] = .init()
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

                if bytes[index + 1] == carriageReturn, bytes[index + 2] == newLine {
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
                if bytes[index] == carriageReturn &&
                    bytes[index + 1] == newLine &&
                    bytes[index + 2] == carriageReturn &&
                    bytes[index + 3] == newLine
                {
                    headerEndIndex = index - 1
                    valueStartIndex = index + 4
                    break
                } else if (bytes[index] == newLine && bytes[index + 1] == newLine) ||
                    (bytes[index] == carriageReturn && bytes[index + 1] == carriageReturn)
                {
                    headerEndIndex = index - 1
                    valueStartIndex = index + 2
                    break
                }
            }

            if headerStartIndex < headerEndIndex,
               let headerLines = String(bytes: bytes[headerStartIndex ... headerEndIndex], encoding: .utf8)
            {
                if let name = HeaderUtil.getParameterValue(named: "name", in: headerLines) {
                    if let filename = HeaderUtil.getParameterValue(named: "filename", in: headerLines) {
                        files[name] = File(filename: filename, data: Data(bytes[valueStartIndex ... valueEndIndex]))
                    } else {
                        parameters[name] = String(bytes: bytes[valueStartIndex ... valueEndIndex], encoding: .utf8)
                    }
                }
            }
        }

        return (parameters, files)
    }
}
