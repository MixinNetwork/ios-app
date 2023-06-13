import Foundation
import MixinServices

struct DeviceTransferFilter {
    
    typealias TimeChangeHandler = (DeviceTransferFilter.Time) -> Void
    typealias ConversationChangeHandler = (DeviceTransferFilter.Conversation) -> Void
    
    enum Conversation {
        
        case all
        case designated(Array<String>)
        
        var title: String {
            switch self {
            case .all:
                return R.string.localizable.all_chats()
            case .designated(let conversations):
                if conversations.count == 1 {
                    return R.string.localizable.chats_count_one()
                } else {
                    return R.string.localizable.chats_count(conversations.count)
                }
            }
        }
        
        var joinedIDs: String? {
            switch self {
            case .all:
                return nil
            case .designated(let ids):
                return ids.joined(separator: "', '")
            }
        }
        
    }
    
    enum Time {
        
        case all
        case lastMonths(Int)
        case lastYears(Int)
        
        var title: String {
            switch self {
            case .all:
                return R.string.localizable.all_dates()
            case .lastMonths(let count):
                if count == 1 {
                    return R.string.localizable.last_month()
                } else {
                    return R.string.localizable.last_month_count(count)
                }
            case .lastYears(let count):
                if count == 1 {
                    return R.string.localizable.last_year()
                } else {
                    return R.string.localizable.last_year_count(count)
                }
            }
        }
        
        var utcString: String? {
            let monthsAgo: Int
            switch self {
            case .all:
                monthsAgo = 0
            case .lastMonths(let months):
                monthsAgo = months
            case .lastYears(let years):
                monthsAgo = years * 12
            }
            if monthsAgo == 0 {
                return nil
            } else {
                let calendar = Calendar.current
                let startOfToday = calendar.startOfDay(for: Date())
                return calendar.date(byAdding: .month, value: -monthsAgo, to: startOfToday)?.toUTCString()
            }
        }
        
    }
    
    var conversation: Conversation
    var time: Time
    
}
