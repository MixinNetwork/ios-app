import Foundation

struct DeviceTransferRange {
    
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
    }
    
    enum Date {
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
    }
    
    var conversation: Conversation
    var date: Date
    
}
