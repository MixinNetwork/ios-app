import Foundation
import MixinServices

class GroupCallMembersManager {
    
    static let membersDidChangeNotification = Notification.Name("one.mixin.messenger.GroupCallMembersManager.MembersDidChange")
    static let didRemoveZombieMemberNotification = Notification.Name("one.mixin.messenger.GroupCallMembersManager.DidRemoveZombieMember")
    static let userIdUserInfoKey = "user_id"
    static let conversationIdUserInfoKey = "conv_id"
    
    // Key is conversation ID, value is an array of user IDs
    // If the value is nil, the list has not been retrieved since App launch
    // If the value is an array regardless of empty or not, the list is in syncing
    // This var should be accessed from working queue
    private(set) var members = [String: [String]]() {
        didSet {
            NotificationCenter.default.post(name: Self.membersDidChangeNotification, object: self)
        }
    }
    
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
        }
        self.members[conversationId] = members
    }
    
    func removeUser(with userId: String, fromConversationWith conversationId: String) {
        members[conversationId]?.removeAll(where: { $0 == userId })
    }
    
    private func loadMembersIfNeverLoaded(forConversationWith id: String) {
        guard members[id] == nil else {
            return
        }
        guard let peers = SendMessageService.shared.requestKrakenPeers(forConversationWith: id) else {
            return
        }
        members[id] = peers.map(\.userId)
    }
    
}

extension GroupCallMembersManager {
    
    func beginPolling(forConversationWith conversationId: String) {
        assert(Thread.isMainThread) // TODO: Remove this restriction
        endPolling(forConversationWith: conversationId)
        let timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true, block: { [weak self] (_) in
            guard let self = self else {
                return
            }
            self.queue.async {
                guard let peers = SendMessageService.shared.requestKrakenPeers(forConversationWith: conversationId) else {
                    return
                }
                let remoteUserIds = Set(peers.map(\.userId))
                var localUserIds = self.members[conversationId] ?? []
                for (index, userId) in localUserIds.enumerated().reversed() where !remoteUserIds.contains(userId) {
                    localUserIds.remove(at: index)
                    let userInfo = [
                        Self.conversationIdUserInfoKey: conversationId,
                        Self.userIdUserInfoKey: userId,
                    ]
                    NotificationCenter.default.post(name: Self.didRemoveZombieMemberNotification,
                                                    object: self,
                                                    userInfo: userInfo)
                }
                self.members[conversationId] = localUserIds
            }
        })
        pollingTimers.setObject(timer, forKey: conversationId as NSString)
    }
    
    func endPolling(forConversationWith id: String) {
        assert(Thread.isMainThread) // TODO: Remove this restriction
        guard let timer = pollingTimers.object(forKey: id as NSString) else {
            return
        }
        timer.invalidate()
    }
    
}
