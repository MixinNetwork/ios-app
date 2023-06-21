import Foundation
import MixinServices

class DeviceTransferFilter {
    
    static let filterDidChangeNotification = Notification.Name("one.mixin.messager.DeviceTransferFilter")
    
    private(set) var dateString: String?
    private(set) var executor: ConversationExecutor
    
    var conversation: Conversation {
        didSet {
            executor = ConversationExecutor(conversation: conversation)
            NotificationCenter.default.post(onMainThread: Self.filterDidChangeNotification, object: nil)
        }
    }
    var time: Time {
        didSet {
            dateString = time.utcString
            NotificationCenter.default.post(onMainThread: Self.filterDidChangeNotification, object: nil)
        }
    }
    
    var shouldFilter: Bool {
        switch (time, conversation) {
        case (.all, .all):
            return false
        default:
            return true
        }
    }
    
    init(conversation: Conversation, time: Time) {
        self.conversation = conversation
        self.time = time
        dateString = time.utcString
        executor = ConversationExecutor(conversation: conversation)
    }
    
    func isValidItem(conversationID: String) -> Bool {
        switch executor {
        case .all, .designated:
            return true
        case .checked(let ids):
            return ids.contains(conversationID)
        }
    }
    
    func isValidTime(createdAt: String) -> Bool {
        if let dateString {
            return createdAt >= dateString
        } else {
            return true
        }
    }
    
}

extension DeviceTransferFilter {
    
    enum ConversationExecutor {
        
        case all
        case designated(Array<String>)
        case checked(Array<String>)
        
        // Due to the limitation of the maximum value of a host parameter number,
        // if the "ids" quantity exceeds "strideForDeviceTransfer" which is 900,
        // then query all data and check according to the conversationID before sending
        init(conversation: Conversation) {
            switch conversation {
            case .all:
                self = .all
            case .designated(let ids):
                if ids.count > UserDatabaseDAO.strideForDeviceTransfer {
                    self = .checked(Array(ids))
                } else {
                    self = .designated(Array(ids))
                }
            }
        }
        
        var ids: [String]? {
            switch self {
            case .all, .checked:
                return nil
            case .designated(let ids):
                return ids
            }
        }
        
    }
    
}

extension DeviceTransferFilter {
    
    enum Conversation {
        
        case all
        case designated(Set<String>)
        
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
                return Array(ids)
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
            let monthsAgo: Int
            switch self {
            case .all:
                return nil
            case .lastMonths(let months):
                monthsAgo = months
            case .lastYears(let years):
                monthsAgo = years * 12
            }
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            return calendar.date(byAdding: .month, value: -monthsAgo, to: startOfToday)?.toUTCString()
        }
        
    }
    
}
