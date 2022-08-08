import Foundation

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
            return R.string.localizable.today()
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
