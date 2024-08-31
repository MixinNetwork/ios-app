import Foundation
import MixinServices

extension Market.Limit {
    
    var displayTitle: String {
        R.string.localizable.top_count(count)
    }
    
}

extension Market.ChangePeriod {
    
    public var displayTitle: String {
        switch self {
        case .oneHour:
            R.string.localizable.change_percent_period_hour(1)
        case .twentyFourHours:
            R.string.localizable.change_percent_period_hour(24)
        case .sevenDays:
            R.string.localizable.change_percent_period_day(7)
        case .thirtyDays:
            R.string.localizable.change_percent_period_day(30)
        }
    }
    
}
