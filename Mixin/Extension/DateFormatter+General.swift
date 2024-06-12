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
    
}

extension ISO8601DateFormatter {
    
    static let `default` = ISO8601DateFormatter()
    
}
