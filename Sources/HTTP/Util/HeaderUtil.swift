import class Foundation.NSRegularExpression
import struct Foundation.NSRange

public final class HeaderUtil {
    static let parameterValuePattern = "(?:\"([^\"]+)\"|([^;]+))"

    private init() {}

    public class func getParameterValue(named name: String, in headerLine: String) -> String? {
        let delimiter = "="
        let pattern = ";\\s*([^=]+)=\(parameterValuePattern)"

        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: headerLine.utf8.count)
            let matches = regex.matches(in: headerLine, range: range)
            let name = name.lowercased()

            for match in matches {
                if let range = Range(match.range, in: headerLine) {
                    let parameter = headerLine[range].dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                    let components = parameter.components(separatedBy: delimiter)
                    let parameterName = components.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                    if parameterName == name {
                        return components.last?
                            .replacingOccurrences(of: "\"", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }

        return nil
    }

    public class func setParameterValue(_ value: String, named name: String, in headerLine: inout String) {
        let pattern = "\(name)=\(parameterValuePattern)"

        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: headerLine.utf8.count)
            let nameValue = "\(name)=\(value)"

            if regex.firstMatch(in: headerLine, range: range) == nil {
                if headerLine.last != ";" { headerLine += "; " }
                headerLine += nameValue
            } else {
                headerLine = regex.stringByReplacingMatches(
                    in: headerLine,
                    range: range,
                    withTemplate: nameValue
                )
            }
        }
    }

    public class func removeParameter(named name: String, in headerLine: inout String) {
        let pattern = "\(name)=\(parameterValuePattern)(; )?"

        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: headerLine.utf8.count)
            headerLine = regex.stringByReplacingMatches(in: headerLine, range: range, withTemplate: "")
        }

        if headerLine.last == " " { headerLine.removeLast() }
        if headerLine.last == ";" { headerLine.removeLast() }
    }
}
