import Foundation

enum ExpiredMessageDurationFormatter {
    
    static func string(from value: Int64) -> String {
        if value == 0 {
            return R.string.localizable.off()
        } else {
            let unit: String
            let representation: TimeInterval
            let interval = TimeInterval(value)
            if interval < .minute {
                representation = interval
                unit = representation == 1
                    ? R.string.localizable.unit_second()
                    : R.string.localizable.unit_second_count()
            } else if interval < .hour {
                representation = interval / .minute
                unit = representation == 1
                    ? R.string.localizable.unit_minute()
                    : R.string.localizable.unit_minute_count()
            } else if interval < .day {
                representation = interval / .hour
                unit = representation == 1
                    ? R.string.localizable.unit_hour()
                    : R.string.localizable.unit_hour_count()
            } else if interval < .week {
                representation = interval / .day
                unit = representation == 1
                    ? R.string.localizable.unit_day()
                    : R.string.localizable.unit_day_count()
            } else {
                representation = interval / .week
                unit = representation == 1
                    ? R.string.localizable.unit_week()
                    : R.string.localizable.unit_week_count()
            }
            return "\(Int(representation)) \(unit)"
        }
    }
    
}
