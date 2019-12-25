import UIKit
import CoreMedia

public extension DateFormatter {

    static let dayDate = DateFormatter(dateFormat: localized("date_format_day"))
    static let weekDate = DateFormatter(dateFormat: "EEEE")
    static let month = DateFormatter(dateFormat: localized("date_format_month"))
    static let date = DateFormatter(dateFormat: "MMM d, yyyy")
    static let dateSimple = DateFormatter(dateFormat: localized("date_format_date"))
    static let dateFull = DateFormatter(dateFormat: "yyyy-MM-dd HH:mm:ss")
    static let yyyymmdd = DateFormatter(dateFormat: "yyyyMMdd")
    static let MMMddHHmm = DateFormatter(dateFormat: localized("date_format_transation"))
    static let filename = DateFormatter(dateFormat: "yyyy-MM-dd_HH:mm:ss")
    static let log = DateFormatter(dateFormat: "yyyy/MM/dd, hh:mm a")
    static let nameOfTheDayAndTime = DateFormatter(dateFormat: "EEEE, " + localized("date_format_day"))
    static let dateAndTime = DateFormatter(dateFormat: localized("date_format_date") + " " + localized("date_format_day"))
    
    convenience init(dateFormat: String) {
        self.init()
        self.dateFormat = dateFormat
        self.locale = Locale.current
        self.timeZone = TimeZone.current
    }

    static let iso8601Full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()

    static let localFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    static let backupFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

public extension Date {

    private static let sourceTimeZone = TimeZone(identifier: "UTC")!
    private static let destinationTimeZone = NSTimeZone.local

    func toUTCString() -> String {
        return DateFormatter.iso8601Full.string(from: self)
    }

    func toLocalDate() -> Date {
        let destinationGMTOffset = Date.destinationTimeZone.secondsFromGMT(for: self)
        let sourceGMTOffset = Date.sourceTimeZone.secondsFromGMT(for: self)
        return Date(timeInterval: TimeInterval(destinationGMTOffset - sourceGMTOffset), since: self)
    }

    func nanosecond() -> Int64 {
        let nanosecond: Int64 = Int64(Calendar.current.dateComponents([.nanosecond], from: self).nanosecond ?? 0)
        return Int64(self.timeIntervalSince1970 * 1000000000) + nanosecond
    }

    func logDatetime() -> String {
        return DateFormatter.log.string(from: self)
    }

    func timeAgo() -> String {
        let now = Date()
        let nowDateComponents = Calendar.current.dateComponents([.day], from: now)
        let dateComponents = Calendar.current.dateComponents([.day], from: self)
        let days = Date().timeIntervalSince(self) / 86400
        if days < 1 && nowDateComponents.day == dateComponents.day {
            return DateFormatter.dayDate.string(from: self)
        } else if days < 7 {
            return DateFormatter.weekDate.string(from: self).capitalized
        } else {
            return DateFormatter.dateSimple.string(from: self)
        }
    }

    func timeHoursAndMinutes() -> String {
        return DateFormatter.dayDate.string(from: self)
    }

    func timeDayAgo() -> String {
        let now = Date()
        let nowDateComponents = Calendar.current.dateComponents([.day, .year, .weekOfYear], from: now)
        let dateComponents = Calendar.current.dateComponents([.day, .year, .weekOfYear], from: self)

        if nowDateComponents.day == dateComponents.day && nowDateComponents.year == dateComponents.year && nowDateComponents.month == dateComponents.month {
            return localized("chat_time_today")
        } else {
            if nowDateComponents.year == dateComponents.year && nowDateComponents.weekOfYear == dateComponents.weekOfYear {
                return DateFormatter.weekDate.string(from: self)
            } else if nowDateComponents.year == dateComponents.year {
                return DateFormatter.month.string(from: self)
            } else {
                return DateFormatter.date.string(from: self)
            }
        }
    }
}

public let mediaDurationFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.minute, .second]
    formatter.zeroFormattingBehavior = [.pad]
    formatter.unitsStyle = .positional
    return formatter
}()

public let millisecondsPerSecond: Double = 1000
