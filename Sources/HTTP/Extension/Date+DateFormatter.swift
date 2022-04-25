import Foundation

extension Date {
    var rfc1123: String { dateFormatter.string(from: self) }

    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"

        return formatter
    }

    init(rfc1123: String) {
        self = Date()

        if let date = dateFormatter.date(from: rfc1123) {
            self = date
        }
    }
}
