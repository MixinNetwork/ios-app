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
    
    private(set) var members = [String: [String]]()
    
    private let queue: DispatchQueue
    private let pollingInterval: TimeInterval = 30
    private let pollingTimers = NSMapTable<NSString, Timer>(keyOptions: .copyIn, valueOptions: .weakMemory)
    
    private var loadedConversationsId = Set<String>()
    
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
    
    // A nil return value indicates there's an error fetching peers
    func members(inConversationWith id: String) -> [UserItem]? {
        loadMembersIfNeverLoaded(forConversationWith: id)
        if let userIds = members[id] {
            return UserDAO.shared.getUsers(with: userIds)
        } else {
            return nil
        }
    }
    
    func addMember(with userId: String, toConversationWith conversationId: String) {
        CallService.shared.log("[GroupCallMembersManager] Add member: \(userId), to: \(conversationId)")
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
        beginPolling(forConversationWith: conversationId)
    }
    
    func removeMember(with userId: String, fromConversationWith conversationId: String) {
        guard var members = self.members[conversationId] else {
            return
        }
        CallService.shared.log("[GroupCallMembersManager] Remove member: \(userId), from: \(conversationId)")
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
        if members.isEmpty {
            endPolling(forConversationWith: conversationId)
        }
    }
    
    private func loadMembersIfNeverLoaded(forConversationWith id: String) {
        guard !loadedConversationsId.contains(id) else {
            return
        }
        guard let peers = KrakenMessageRetriever.shared.requestPeers(forConversationWith: id) else {
            return
        }
        let remoteUserIds = peers.map(\.userId)
        CallService.shared.log("[GroupCallMembersManager] Load members: \(remoteUserIds), for conversation: \(id)")
        loadedConversationsId.insert(id)
        
        let newMembers: [String]
        if let members = self.members[id] {
            let set = Set(remoteUserIds)
            newMembers = members.filter(set.contains)
        } else {
            newMembers = remoteUserIds
        }
        self.members[id] = newMembers
        
        if !peers.isEmpty {
            beginPolling(forConversationWith: id)
        }
        let userInfo: [String: Any] = [
            Self.UserInfoKey.conversationId: id,
            Self.UserInfoKey.userIds: newMembers
        ]
        NotificationCenter.default.post(name: Self.membersDidChangeNotification, object: self, userInfo: userInfo)
    }
    
}

extension GroupCallMembersManager {
    
    func beginPolling(forConversationWith conversationId: String) {
        let key = conversationId as NSString
        guard self.pollingTimers.object(forKey: key) == nil else {
            return
        }
        let timer = Timer(timeInterval: pollingInterval, repeats: true) { [weak self] (timer) in
            guard let self = self else {
                CallService.shared.log("[PeerPolling] manager of \(conversationId) is nil out")
                timer.invalidate()
                return
            }
            self.queue.async {
                guard let peers = KrakenMessageRetriever.shared.requestPeers(forConversationWith: conversationId) else {
                    CallService.shared.log("[PeerPolling] Peer request failed. cid: \(conversationId)")
                    return
                }
                let remoteUserIds = Set(peers.map(\.userId))
                CallService.shared.log("[PeerPolling] cid: \(conversationId), remote id: \(remoteUserIds)")
                var localUserIds = self.members[conversationId] ?? []
                CallService.shared.log("[PeerPolling] cid: \(conversationId), local id: \(localUserIds)")
                localUserIds = localUserIds.filter(remoteUserIds.contains)
                self.members[conversationId] = localUserIds
                if localUserIds.isEmpty {
                    timer.invalidate()
                    CallService.shared.log("[PeerPolling] Member polling for \(conversationId) ends")
                }
                let userInfo: [String: Any] = [
                    Self.UserInfoKey.conversationId: conversationId,
                    Self.UserInfoKey.userIds: localUserIds
                ]
                NotificationCenter.default.post(name: Self.membersDidChangeNotification,
                                                object: self,
                                                userInfo: userInfo)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollingTimers.setObject(timer, forKey: key)
        CallService.shared.log("[PeerPolling] Begin polling members for \(conversationId)")
    }
    
    private func endPolling(forConversationWith id: String) {
        guard let timer = pollingTimers.object(forKey: id as NSString) else {
            return
        }
        timer.invalidate()
        CallService.shared.log("[PeerPolling] End polling members for \(id)")
    }
    
}
