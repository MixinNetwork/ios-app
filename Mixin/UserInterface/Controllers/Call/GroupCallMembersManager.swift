import Foundation
import MixinServices

class GroupCallMembersManager {
    
    // This is a global storage for Group Call's members
    // Members are first retrived when user opens a conversation or a KRAKEN_PUBLISH is received,
    // then they are in sync with corresponding Kraken Messages
    
    enum UserInfoKey {
        static let userIds = "user_ids"
        static let conversationId = "conv_id"
    }
    
    static let membersDidChangeNotification = Notification.Name("one.mixin.messenger.GroupCallMembersManager.MembersDidChange")
    static let didRemoveZombieMemberNotification = Notification.Name("one.mixin.messenger.GroupCallMembersManager.DidRemoveZombieMember")
    
    // Key is conversation ID, value is an array of user IDs
    // If the value is nil, the list has not been retrieved since App launch
    // If the value is an array regardless of empty or not, the list is in syncing
    // This var should be accessed from working queue
    private(set) var members = [String: [String]]()
    
    private let queue: DispatchQueue
    private let pollingInterval: TimeInterval = 30
    private let pollingTimers = NSMapTable<NSString, Timer>(keyOptions: .copyIn, valueOptions: .weakMemory)
    
    init(workingQueue: DispatchQueue) {
        self.queue = workingQueue
    }
    
    func loadMembersAsynchornouslyIfNeverLoaded(forConversationWith id: String) {
        queue.async {
            self.loadMembersIfNeverLoaded(forConversationWith: id)
        }
    }
    
    // This func is designed to be called in Conversation interface
    // To improve responsiveness, it won't retrive kraken list from server
    // As long as loadMembersAsynchornouslyIfNeverLoaded is called before,
    // members returned by completion closure should be accurate
    func getMemberUserIds(forConversationWith id: String, completion: @escaping ([String]) -> Void) {
        queue.async {
            let ids = self.members[id] ?? []
            DispatchQueue.main.async {
                completion(ids)
            }
        }
    }
    
    func members(inConversationWith id: String) -> [UserItem] {
        loadMembersIfNeverLoaded(forConversationWith: id)
        if let userIds = members[id] {
            return userIds.compactMap(UserDAO.shared.getUser(userId:))
        } else {
            return []
        }
    }
    
    func addMember(with userId: String, toConversationWith conversationId: String) {
        var members = self.members[conversationId] ?? []
        if !members.contains(userId) {
            members.append(userId)
            self.members[conversationId] = members
            let userInfo: [String: Any] = [
                Self.UserInfoKey.conversationId: conversationId,
                Self.UserInfoKey.userIds: members
            ]
            NotificationCenter.default.post(name: Self.membersDidChangeNotification, object: self, userInfo: userInfo)
        }
    }
    
    func removeMember(with userId: String, fromConversationWith conversationId: String) {
        guard var members = self.members[conversationId] else {
            return
        }
        let countBefore = members.count
        members.removeAll(where: { $0 == userId })
        if members.count != countBefore {
            self.members[conversationId] = members
            let userInfo: [String: Any] = [
                Self.UserInfoKey.conversationId: conversationId,
                Self.UserInfoKey.userIds: members
            ]
            NotificationCenter.default.post(name: Self.membersDidChangeNotification, object: self, userInfo: userInfo)
        }
    }
    
    private func loadMembersIfNeverLoaded(forConversationWith id: String) {
        guard members[id] == nil else {
            return
        }
        guard let peers = SendMessageService.shared.requestKrakenPeers(forConversationWith: id) else {
            return
        }
        let userIds = peers.map(\.userId)
        members[id] = userIds
        let userInfo: [String: Any] = [
            Self.UserInfoKey.conversationId: id,
            Self.UserInfoKey.userIds: userIds
        ]
        NotificationCenter.default.post(name: Self.membersDidChangeNotification, object: self, userInfo: userInfo)
    }
    
}

extension GroupCallMembersManager {
    
    func beginPolling(forConversationWith conversationId: String) {
        endPolling(forConversationWith: conversationId)
        let timer = Timer(timeInterval: pollingInterval, repeats: true) { [weak self] (_) in
            guard let self = self else {
                return
            }
            self.queue.async {
                guard let peers = SendMessageService.shared.requestKrakenPeers(forConversationWith: conversationId) else {
                    return
                }
                let remoteUserIds = Set(peers.map(\.userId))
                var localUserIds = self.members[conversationId] ?? []
                var removedUserIds = [String]()
                for (index, userId) in localUserIds.enumerated().reversed() where !remoteUserIds.contains(userId) {
                    localUserIds.remove(at: index)
                    removedUserIds.append(userId)
                }
                if !removedUserIds.isEmpty {
                    self.members[conversationId] = localUserIds
                    let userInfo: [String: Any] = [
                        Self.UserInfoKey.conversationId: conversationId,
                        Self.UserInfoKey.userIds: removedUserIds,
                    ]
                    NotificationCenter.default.post(name: Self.didRemoveZombieMemberNotification,
                                                    object: self,
                                                    userInfo: userInfo)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollingTimers.setObject(timer, forKey: conversationId as NSString)
    }
    
    func endPolling(forConversationWith id: String) {
        guard let timer = pollingTimers.object(forKey: id as NSString) else {
            return
        }
        timer.invalidate()
    }
    
}
