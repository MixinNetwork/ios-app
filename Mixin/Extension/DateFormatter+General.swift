import Foundation

extension DateFormatter {
    
    static let dateFull = DateFormatter(dateFormat: "yyyy-MM-dd HH:mm:ss")
    static let yyyymmdd = DateFormatter(dateFormat: "yyyyMMdd")
    static let date = DateFormatter(dateFormat: "MMM d, yyyy")
    static let week = DateFormatter(dateFormat: "EEEE")
    
    static let month = DateFormatter(dateFormat: R.string.localizable.date_format_month())
    static let dayDate = DateFormatter(dateFormat: R.string.localizable.date_format_day())
    static let weekDate = DateFormatter(dateFormat: R.string.localizable.date_format_week_date())
    static let dateSimple = DateFormatter(dateFormat: R.string.localizable.date_format_date())
    static let nameOfTheDayAndTime = DateFormatter(dateFormat: "EEEE, " + R.string.localizable.date_format_day())
    static let dateAndTime = DateFormatter(dateFormat: R.string.localizable.date_format_date() + " " + R.string.localizable.date_format_day())
    
    static let log = DateFormatter(dateFormat: "yyyy/MM/dd, hh:mm a")
    
    static let deleteAccount: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    static let shortDateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let shortTimeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    // Returns nil if `from` `to` are both nil
    static func shortDatePeriod(from start: Date?, to end: Date?) -> String? {
        let formatter: DateFormatter = .shortDateOnly
        return switch (start, end) {
        case (.none, .none):
            nil
        case let (.some(start), .none):
            R.string.localizable.from_date(formatter.string(from: start))
        case let (.none, .some(end)):
            R.string.localizable.until_date(formatter.string(from: end))
        case let (.some(start), .some(end)):
            formatter.string(from: start) + " ~ " + formatter.string(from: end)
        }
    }
    
}

extension ISO8601DateFormatter {
    
    static let `default` = ISO8601DateFormatter()
    
}
