import Foundation

extension Date {
    /// Formats the date as an RFC 1123-compliant HTTP date string (e.g. `"Mon, 01 Jan 2024 00:00:00 GMT"`).
    var rfc1123: String { Date.rfc1123Formatter.string(from: self) }

    /// A shared, thread-safe RFC 1123 date formatter. `DateFormatter` is expensive to create and is
    /// safe to share across threads when its properties are not mutated after initialisation.
    static let rfc1123Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return formatter
    }()

    /// Initializes a `Date` from an RFC 1123-formatted string. Falls back to the current date when
    /// the string cannot be parsed.
    ///
    /// - Parameter rfc1123: An RFC 1123 date string.
    init(rfc1123: String) {
        self = Date.rfc1123Formatter.date(from: rfc1123) ?? Date()
    }
}
