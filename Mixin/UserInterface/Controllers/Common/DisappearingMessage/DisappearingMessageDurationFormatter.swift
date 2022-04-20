import Foundation

enum DisappearingMessageDurationFormatter {
    
    static func string(from value: Int64) -> String {
        if value == 0 {
            return R.string.localizable.setting_backup_off()
        } else {
            let unit: String
            let representation: TimeInterval
            let interval = TimeInterval(value)
            if interval < .minute {
                representation = interval
                unit = representation == 1
                    ? R.string.localizable.disappearing_message_second_unit()
                    : R.string.localizable.disappearing_message_seconds_unit()
            } else if interval < .hour {
                representation = interval / .minute
                unit = representation == 1
                    ? R.string.localizable.disappearing_message_minute_unit()
                    : R.string.localizable.disappearing_message_minutes_unit()
            } else if interval < .day {
                representation = interval / .hour
                unit = representation == 1
                    ? R.string.localizable.disappearing_message_hour_unit()
                    : R.string.localizable.disappearing_message_hours_unit()
            } else if interval < .week {
                representation = interval / .day
                unit = representation == 1
                    ? R.string.localizable.disappearing_message_day_unit()
                    : R.string.localizable.disappearing_message_days_unit()
            } else {
                representation = interval / .week
                unit = representation == 1
                    ? R.string.localizable.disappearing_message_week_unit()
                    : R.string.localizable.disappearing_message_weeks_unit()
            }
            return "\(Int(representation)) \(unit)"
        }
    }
    
}
