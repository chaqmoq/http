import Foundation

public final class HeaderUtil {
    static let parameterValuePattern = "(?:\"([^\"]+)\"|([^;]+))"

    // The pattern for getParameterValue is always the same string, so compile it once.
    private static let getParameterRegex: NSRegularExpression = {
        let pattern = ";\\s*([^=]+)=\(parameterValuePattern)"
        // Pattern is a compile-time constant; force-unwrap is safe.
        return try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()

    // Patterns for setParameterValue / removeParameter embed a caller-supplied name,
    // so they vary. Cache by full pattern string to avoid recompiling on repeated calls
    // with the same name (e.g. the same cookie name set many times).
    // NSCache is thread-safe and evicts under memory pressure automatically.
    private static let regexCache = NSCache<NSString, NSRegularExpression>()

    private static func cachedRegex(for pattern: String) -> NSRegularExpression? {
        if let cached = regexCache.object(forKey: pattern as NSString) {
            return cached
        }
        guard let compiled = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        regexCache.setObject(compiled, forKey: pattern as NSString)
        return compiled
    }

    public class func getParameterValue(named name: String, in headerLine: String) -> String? {
        let regex = getParameterRegex
        let range = NSRange(location: 0, length: headerLine.utf8.count)
        let matches = regex.matches(in: headerLine, range: range)
        let name = name.lowercased()

        for match in matches {
            if let range = Range(match.range, in: headerLine) {
                // Drop the leading ';' and trim surrounding whitespace.
                let parameter = String(headerLine[range].dropFirst())
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // Split only on the first '=' so that parameter values containing '='
                // (e.g. base64-encoded filenames) are returned intact.
                guard let equalsIndex = parameter.firstIndex(of: "=") else { continue }
                let parameterName = String(parameter[..<equalsIndex])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()

                if parameterName == name {
                    return String(parameter[parameter.index(after: equalsIndex)...])
                        .replacingOccurrences(of: "\"", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
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
        guard !name.isEmpty, !name.contains(delimiter) else { return }
        let value = enclosingInQuotes ? "\"" + value + "\"" : value
        let nameValue = "\(name)\(delimiter)\(value)"

        if headerLine.isEmpty {
            headerLine = nameValue
        } else {
            let terminator: Character = ";"
            let pattern = "(^|\\s)\(name)\(delimiter)\(parameterValuePattern)(\(terminator))?"
            guard let regex = cachedRegex(for: pattern) else { return }
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
        guard !name.isEmpty, !name.contains(delimiter) else { return }
        let pattern = "(^|\\s)\(name)\(delimiter)\(parameterValuePattern)(\(terminator))?"
        guard let regex = cachedRegex(for: pattern) else { return }
        let range = NSRange(location: 0, length: headerLine.utf8.count)
        headerLine = regex.stringByReplacingMatches(in: headerLine, range: range, withTemplate: "")
        headerLine = headerLine.trimmingCharacters(in: .whitespacesAndNewlines)

        if headerLine.last == terminator {
            headerLine.removeLast()
        }
    }
}
