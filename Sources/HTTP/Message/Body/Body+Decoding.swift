import Foundation

extension Body {
    public var json: Parameters<String, Any>? {
        try? JSONSerialization.jsonObject(with: data, options: []) as? Parameters<String, Any>
    }

    public var urlEncoded: Parameters<String, Any>? {
        if let string = string.removingPercentEncoding?.replacingOccurrences(of: "+", with: " ") {
            var urlComponents = URLComponents()
            urlComponents.query = string

            if let queryItems = urlComponents.queryItems, !queryItems.isEmpty {
                var parameters = Parameters<String, Any>()

                for queryItem in queryItems {
                    parameters[queryItem.name] = queryItem.value
                }

                return parameters
            }
        }

        return nil
    }

    public func multipart(boundary: String) -> (Parameters<String, Any>?, Parameters<String, File>?) {
        guard !isEmpty else { return (nil, nil) }
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

                if bytes[index + 1] == carriageReturn && bytes[index + 2] == newLine {
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
        guard !contentRanges.isEmpty else { return (nil, nil) }
        var parameters: Parameters<String, Any>?
        var files: Parameters<String, File>?

        for index in stride(from: 1, through: contentRanges.count - 1, by: 2) {
            let headerStartIndex = contentRanges[index - 1]
            var headerEndIndex = headerStartIndex
            let valueEndIndex = contentRanges[index]
            var valueStartIndex = valueEndIndex

            for index in headerStartIndex...valueEndIndex {
                if bytes[index] == carriageReturn &&
                    bytes[index + 1] == newLine &&
                    bytes[index + 2] == carriageReturn &&
                    bytes[index + 3] == newLine {
                    headerEndIndex = index - 1
                    valueStartIndex = index + 4
                    break
                } else if (bytes[index] == newLine && bytes[index + 1] == newLine) ||
                    (bytes[index] == carriageReturn && bytes[index + 1] == carriageReturn) {
                    headerEndIndex = index - 1
                    valueStartIndex = index + 2
                    break
                }
            }

            if headerStartIndex < headerEndIndex,
                let headerLines = String(bytes: bytes[headerStartIndex...headerEndIndex], encoding: .utf8) {
                if let name = HeaderUtil.getParameterValue(named: "name", in: headerLines) {
                    if let filename = HeaderUtil.getParameterValue(named: "filename", in: headerLines) {
                        if files == nil { files = [:] }
                        files?[name] = File(filename: filename, data: Data(bytes[valueStartIndex...valueEndIndex]))
                    } else {
                        if parameters == nil { parameters = [:] }
                        parameters?[name] = String(bytes: bytes[valueStartIndex...valueEndIndex], encoding: .utf8)
                    }
                }
            }
        }

        return (parameters, files)
    }
}
