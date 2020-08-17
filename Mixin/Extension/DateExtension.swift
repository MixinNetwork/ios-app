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
}

extension Date {

    func timeAgo() -> String {
        let now = Date()
        let nowDateComponents = Calendar.current.dateComponents([.day], from: now)
        let dateComponents = Calendar.current.dateComponents([.day], from: self)
        let days = Date().timeIntervalSince(self) / 86400
        if days < 1 && nowDateComponents.day == dateComponents.day {
            return DateFormatter.dayDate.string(from: self)
        } else if days < 7 {
            return DateFormatter.week.string(from: self).capitalized
        } else {
            return DateFormatter.dateSimple.string(from: self)
        }
    }

    func simpleTimeAgo() -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.year, .month, .day, .hour, .minute, .second]
        formatter.zeroFormattingBehavior = .dropAll
        formatter.maximumUnitCount = 1
        return String(format: formatter.string(from: self, to: Date()) ?? "", locale: .current)
    }

    func chatTimeAgo() -> String {
        let now = Date()
        let nowDateComponents = Calendar.current.dateComponents([.day, .month, .year, .weekOfYear], from: now)
        let dateComponents = Calendar.current.dateComponents([.day, .month, .year, .weekOfYear], from: self)

        if nowDateComponents.day == dateComponents.day && nowDateComponents.year == dateComponents.year && nowDateComponents.month == dateComponents.month {
            return R.string.localizable.chat_time_today()
        } else {
            if nowDateComponents.year == dateComponents.year {
                return DateFormatter.month.string(from: self)
            } else {
                return DateFormatter.weekDate.string(from: self)
            }
        }
    }

    func timeHoursAndMinutes() -> String {
        return DateFormatter.dayDate.string(from: self)
    }
}

extension TimeInterval {
    
    static let oneDay: TimeInterval = 24 * 60 * 60
    
}
