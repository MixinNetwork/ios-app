import Foundation

struct LimitOrder: Decodable {
    
    enum Category: String, Decodable {
        case active
        case history
        case all
    }
    
    enum State: String, Decodable {
        case created
        case pricing
        case quoting
        case settled
        case cancelled
        case expired
        case failed
    }
    
    enum Expiry: CaseIterable {
        
        case never
        case tenMinutes
        case oneHour
        case oneDay
        case threeDays
        case oneWeek
        case oneMonth
        
        var localizedName: String {
            switch self {
            case .never:
                R.string.localizable.swap_expiry_never()
            case .tenMinutes:
                R.string.localizable.minute_count(10)
            case .oneHour:
                R.string.localizable.one_hour()
            case .oneDay:
                R.string.localizable.one_day()
            case .threeDays:
                R.string.localizable.days_count(3)
            case .oneWeek:
                R.string.localizable.one_week()
            case .oneMonth:
                R.string.localizable.one_month()
            }
        }
        
        var date: Date {
            switch self {
            case .never:
                    .distantFuture
            case .tenMinutes:
                    .now.addingTimeInterval(10 * .minute)
            case .oneHour:
                    .now.addingTimeInterval(.hour)
            case .oneDay:
                    .now.addingTimeInterval(.day)
            case .threeDays:
                    .now.addingTimeInterval(.day)
            case .oneWeek:
                    .now.addingTimeInterval(.week)
            case .oneMonth:
                    .now.addingTimeInterval(.month)
            }
        }
        
    }
    
}
