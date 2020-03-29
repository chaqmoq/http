import Foundation

extension Response {
    public var description: String {
        var description = ""

        for (header, value) in headers {
            description.append("\(header.rawValue): \(value)\n")
        }

        description.append("\n\(body.description)")

        return "HTTP/\(version.major).\(version.minor) \(status)\n\(description)"
    }
}
