import Foundation

public final class HeaderUtil {
    static let parameterValuePattern = "(?:\"([^\"]+)\"|([^;]+))"

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

    public class func setParameterValue(
        _ value: String,
        named name: String,
        enclosingInQuotes: Bool = false,
        in headerLine: inout String
    ) {
        let delimiter: Character = "="
        guard !name.isEmpty && !name.contains(delimiter) else { return }
        let value = enclosingInQuotes ? "\"" + value + "\"" : value
        let nameValue = "\(name)\(delimiter)\(value)"

        if headerLine.isEmpty {
            headerLine = nameValue
        } else {
            let terminator: Character = ";"
            let pattern = "(^|\\s)\(name)\(delimiter)\(parameterValuePattern)(\(terminator))?"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return }
            let range = NSRange(location: 0, length: headerLine.utf8.count)
            let matches = regex.matches(in: headerLine, range: range)

            if matches.isEmpty {
                headerLine = headerLine.trimmingCharacters(in: .whitespacesAndNewlines)

                if headerLine.last == terminator {
                    headerLine += " " + nameValue
                } else {
                    headerLine += "\(terminator) " + nameValue
                }
            } else {
                for match in matches {
                    if let range = Range(match.range, in: headerLine) {
                        var parameter = String(headerLine[range])

                        if let delimiterIndex = parameter.firstIndex(of: delimiter) {
                            if parameter.last == terminator {
                                parameter = String(parameter[...delimiterIndex]) + value + String(terminator)
                            } else {
                                parameter = String(parameter[...delimiterIndex]) + value
                            }

                            headerLine = regex.stringByReplacingMatches(
                                in: headerLine,
                                range: match.range,
                                withTemplate: parameter
                            )
                        }
                    }
                }
            }
        }
    }

    public class func removeParameter(named name: String, in headerLine: inout String) {
        let delimiter: Character = "="
        let terminator: Character = ";"
        guard !name.isEmpty && !name.contains(delimiter) else { return }
        let pattern = "(^|\\s)\(name)\(delimiter)\(parameterValuePattern)(\(terminator))?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return }
        let range = NSRange(location: 0, length: headerLine.utf8.count)
        headerLine = regex.stringByReplacingMatches(in: headerLine, range: range, withTemplate: "")
        headerLine = headerLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if headerLine.last == terminator { headerLine.removeLast() }
    }
}
