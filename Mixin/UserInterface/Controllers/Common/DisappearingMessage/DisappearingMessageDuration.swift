import Foundation

enum DisappearingMessageDuration: Equatable {
    
    case off
    case thirtySeconds
    case tenMinutes
    case twoHours
    case oneDay
    case oneWeek
    case custom(expireIn: Int64)
    
    init(expireIn: Int64) {
        switch TimeInterval(expireIn) {
        case 0:
            self = .off
        case .minute / 2:
            self = .thirtySeconds
        case .minute * 10:
            self = .tenMinutes
        case .hour * 2:
            self = .twoHours
        case .day:
            self = .oneDay
        case .week:
            self = .oneWeek
        default:
            self = .custom(expireIn: expireIn)
        }
    }
    
    init(index: Int) {
        switch index {
        case 0:
            self = .off
        case 1:
            self = .thirtySeconds
        case 2:
            self = .tenMinutes
        case 3:
            self = .twoHours
        case 4:
            self = .oneDay
        case 5:
            self = .oneWeek
        default:
            self = .custom(expireIn: 0)
        }
    }
    
    var index: Int {
        switch self {
        case .off:
            return 0
        case .thirtySeconds:
            return 1
        case .tenMinutes:
            return 2
        case .twoHours:
            return 3
        case .oneDay:
            return 4
        case .oneWeek:
            return 5
        case .custom:
            return 6
        }
    }
    
    var title: String {
        switch self {
        case .off:
            return R.string.localizable.setting_backup_off()
        case .thirtySeconds:
            return R.string.localizable.disappearing_message_30seconds()
        case .tenMinutes:
            return R.string.localizable.disappearing_message_10minutes()
        case .twoHours:
            return R.string.localizable.disappearing_message_2hours()
        case .oneDay:
            return R.string.localizable.disappearing_message_1day()
        case .oneWeek:
            return R.string.localizable.disappearing_message_1week()
        case .custom:
            return R.string.localizable.disappearing_message_custom_time()
        }
    }
    
    var interval: TimeInterval {
        switch self {
        case .off:
            return 0
        case .thirtySeconds:
            return 30
        case .tenMinutes:
            return 10 * .minute
        case .twoHours:
            return 2 * .hour
        case .oneDay:
            return .day
        case .oneWeek:
            return .week
        case let .custom(expireIn):
            return TimeInterval(expireIn)
        }
    }
    
    var expireInTitle: String {
        guard case let .custom(expireIn) = self else {
            return ""
        }
        if expireIn == 0 {
            return R.string.localizable.setting_backup_off()
        } else {
            let unit: String
            let duration: TimeInterval
            let interval = TimeInterval(expireIn)
            if interval < .minute {
                unit = R.string.localizable.disappearing_message_seconds_unit()
                duration = interval
            } else if interval < .hour {
                unit = R.string.localizable.disappearing_message_minutes_unit()
                duration = interval / .minute
            } else if interval < .day {
                unit = R.string.localizable.disappearing_message_hours_unit()
                duration = interval / .hour
            } else if interval < .week {
                unit = R.string.localizable.disappearing_message_days_unit()
                duration = interval / .day
            } else {
                unit = R.string.localizable.disappearing_message_weeks_unit()
                duration = interval / .week
            }
            return "\(Int(duration)) \(unit)"
        }
    }
    
}
