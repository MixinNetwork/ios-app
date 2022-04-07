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
                unit = R.string.localizable.disappearing_message_seconds_unit()
                representation = interval
            } else if interval < .hour {
                unit = R.string.localizable.disappearing_message_minutes_unit()
                representation = interval / .minute
            } else if interval < .day {
                unit = R.string.localizable.disappearing_message_hours_unit()
                representation = interval / .hour
            } else if interval < .week {
                unit = R.string.localizable.disappearing_message_days_unit()
                representation = interval / .day
            } else {
                unit = R.string.localizable.disappearing_message_weeks_unit()
                representation = interval / .week
            }
            return "\(Int(representation)) \(unit)"
        }
    }
    
}
