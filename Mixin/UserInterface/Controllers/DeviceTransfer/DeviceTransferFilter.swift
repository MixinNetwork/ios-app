import Foundation
import MixinServices

class DeviceTransferFilter {
    
    static let filterDidChangeNotification = Notification.Name("one.mixin.messager.DeviceTransferFilter")

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
        
        var ids: [String]? {
            switch self {
            case .all:
                return nil
            case .designated(let ids):
                return ids
            }
        }
        
        var idsForFetching: [String]? {
            switch self {
            case .all:
                return nil
            case .designated(let ids):
                return ids.count > UserDatabaseDAO.strideForDeviceTransfer ? nil : ids
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
    
    var conversation: Conversation {
        didSet {
            NotificationCenter.default.post(onMainThread: Self.filterDidChangeNotification, object: nil)
        }
    }
    var time: Time {
        didSet {
            NotificationCenter.default.post(onMainThread: Self.filterDidChangeNotification, object: nil)
        }
    }
    
    init(conversation: Conversation, time: Time) {
        self.conversation = conversation
        self.time = time
    }
    
    var shouldFilter: Bool {
        switch (time, conversation) {
        case (.all, .all):
            return false
        default:
            return true
        }
    }
    
    func isValidItem(conversationID: String) -> Bool {
        if case .designated(let ids) = conversation, ids.count > UserDatabaseDAO.strideForDeviceTransfer {
            return ids.contains(conversationID)
        } else {
            return true
        }
    }
    
}
