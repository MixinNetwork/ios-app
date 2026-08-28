import Foundation
import MixinServices

extension MarketChangePeriod {
    
    public var displayTitle: String {
        switch self {
        case .twentyFourHours:
            R.string.localizable.hours_count_short(24)
        case .sevenDays:
            R.string.localizable.days_count_short(7)
        }
    }
    
}
