import Foundation
import MixinServices

class DeviceTransferFilter {
    
    static let filterDidChangeNotification = Notification.Name("one.mixin.messenger.DeviceTransferFilter.Change")
    
    private(set) var earliestCreatedAt: String?
    
    var conversation: Conversation {
        didSet {
            NotificationCenter.default.post(name: Self.filterDidChangeNotification, object: self)
        }
    }
    
    var time: Time {
        didSet {
            earliestCreatedAt = time.utcString
            NotificationCenter.default.post(name: Self.filterDidChangeNotification, object: self)
        }
    }
    
    var isPassthrough: Bool {
        switch (time, conversation) {
        case (.all, .all):
            return true
        default:
            return false
        }
    }
    
    private init(conversation: Conversation, time: Time) {
        self.conversation = conversation
        self.time = time
    }
    
    static func passthrough() -> DeviceTransferFilter {
        DeviceTransferFilter(conversation: .all, time: .all)
    }
    
    func replaceSelectedConversations(with ids: Set<String>) {
        if ids.count > UserDatabaseDAO.deviceTransferStride {
            conversation = .byApplication(ids)
        } else {
            conversation = .byDatabase(ids)
        }
    }
    
}

extension DeviceTransferFilter {
    
    enum Conversation {
        
        // There are two mechanisms for filtering Conversations/Messages:
        // 1. When the number of selected conversations is less than `deviceTransferStride`,
        //    SQL statements are in charge of filtering.
        // 2. When the number of selected conversations is greater than `deviceTransferStride`,
        //    SQL queries do not apply any filter, the filter is applied at the application layer.
        
        case all
        case byDatabase(Set<String>)
        case byApplication(Set<String>)
        
        var title: String {
            switch self {
            case .all:
                return R.string.localizable.all_chats()
            case .byDatabase(let ids), .byApplication(let ids):
                if ids.count == 1 {
                    return R.string.localizable.chats_count_one()
                } else {
                    return R.string.localizable.chats_count(ids.count)
                }
            }
        }
        
        var databaseFilteringIDs: Set<String>? {
            switch self {
            case .all, .byApplication:
                return nil
            case .byDatabase(let ids):
                return ids
            }
        }
        
        var applicationFilteringIDs: Set<String>? {
            switch self {
            case .byApplication(let ids):
                return ids
            case .all, .byDatabase:
                return nil
            }
        }
        
    }
    
}

extension DeviceTransferFilter {
    
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
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            switch self {
            case .all:
                return nil
            case .lastMonths(let months):
                return calendar.date(byAdding: .month, value: -months, to: startOfToday)?.toUTCString()
            case .lastYears(let years):
                return calendar.date(byAdding: .year, value: -years, to: startOfToday)?.toUTCString()
            }
        }
        
    }
    
}
