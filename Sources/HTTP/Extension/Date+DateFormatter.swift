import Foundation

extension Date {
    var rfc1123: String { dateFormatter.string(from: self) }
    var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"

        return dateFormatter
    }

    init(rfc1123: String) {
        self = Date()
        if let date = dateFormatter.date(from: rfc1123) { self = date }
    }
}
