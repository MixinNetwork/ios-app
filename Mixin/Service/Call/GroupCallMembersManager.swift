import Foundation
import MixinServices

// This is a global storage for group call's members
// Members are first retrived when user opens a conversation or a KRAKEN_PUBLISH is received,
// then they are in sync with corresponding Kraken messages
// User himself is NOT stored here

class GroupCallMembersManager {
    
    enum UserInfoKey {
        static let userIds = "uids"
        static let conversationId = "cid"
    }
    
    static let membersDidChangeNotification = Notification.Name("one.mixin.messenger.GroupCallMembersManager.MembersDidChange")
    
    // Modification to memberIds will happen on this queue
    private let messenger = KrakenMessageRetriever()
    private let queue = Queue(label: "one.mixin.messenger.GroupCallMembersManager")
    private let pollingInterval: TimeInterval = 30
    private let pollingTimers = NSMapTable<NSString, Timer>(keyOptions: .copyIn, valueOptions: .weakMemory)
    
    // Access on main queue
    private var memberIds = [String: [String]]()
    
    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(participantDidChange(_:)),
                                               name: ParticipantDAO.participantDidChangeNotification,
                                               object: nil)
    }
    
    func loadMembersAsynchornously(forConversationWith id: String) {
        queue.async {
            self.load(forConversationWith: id)
        }
    }
    
    func memberIds(forConversationWith id: String) -> [String] {
        assert(Thread.isMainThread)
        return memberIds[id] ?? []
    }
    
    func requestMemberIds(forConversationWith id: String) -> [String] {
        assert(!Thread.isMainThread, "This function may blocks, call it on background queue")
        
        var savedMemberIds: [String]? {
            Queue.main.autoSync { self.memberIds[id] }
        }
        
        if let ids = savedMemberIds {
            return ids
        } else {
            queue.autoSync {
                load(forConversationWith: id)
            }
            return savedMemberIds ?? []
        }
    }
    
    private func load(forConversationWith id: String) {
        assert(queue.isCurrent)
        let isConversationLoaded = DispatchQueue.main.sync {
            self.memberIds[id] != nil
        }
        guard !isConversationLoaded else {
            return
        }
        if ParticipantDAO.shared.userId(myUserId, isParticipantOfConversationId: id) {
            guard let peers = messenger.requestPeers(forConversationWith: id) else {
                Logger.call.info(category: "GroupCallMembersManager", message: "Load members failed for conversation: \(id)")
                return
            }
            Logger.call.info(category: "GroupCallMembersManager", message: "\(peers.count) members are loaded for conversation: \(id)")
            let memberIds = peers.map(\.userId)
            DispatchQueue.main.sync {
                self.memberIds[id] = memberIds
                let userInfo: [String: Any] = [
                    Self.UserInfoKey.conversationId: id,
                    Self.UserInfoKey.userIds: memberIds
                ]
                NotificationCenter.default.post(name: Self.membersDidChangeNotification,
                                                object: self,
                                                userInfo: userInfo)
                if !memberIds.isEmpty {
                    self.beginPolling(forConversationWith: id)
                }
            }
        } else {
            DispatchQueue.main.sync {
                guard self.memberIds[id] != [] else {
                    return
                }
                self.memberIds[id] = []
                let userInfo: [String: Any] = [
                    Self.UserInfoKey.conversationId: id,
                    Self.UserInfoKey.userIds: []
                ]
                NotificationCenter.default.post(name: Self.membersDidChangeNotification,
                                                object: self,
                                                userInfo: userInfo)
            }
        }
    }
    
    @objc func participantDidChange(_ notification: Notification) {
        guard let conversationId = notification.userInfo?[ParticipantDAO.UserInfoKey.conversationId] as? String else {
            return
        }
        guard let memberIds = memberIds[conversationId], !memberIds.isEmpty else {
            return
        }
        queue.async {
            guard !ParticipantDAO.shared.userId(myUserId, isParticipantOfConversationId: conversationId) else {
                return
            }
            self.memberIds[conversationId] = []
            let userInfo: [String: Any] = [
                Self.UserInfoKey.conversationId: conversationId,
                Self.UserInfoKey.userIds: []
            ]
            NotificationCenter.default.post(onMainThread: Self.membersDidChangeNotification,
                                            object: self,
                                            userInfo: userInfo)
        }
    }
    
}

// MARK: - Update
extension GroupCallMembersManager {
    
    func addMember(with userId: String, toConversationWith conversationId: String) {
        Logger.call.info(category: "GroupCallMembersManager", message: "Add member: \(userId), to: \(conversationId)")
        Queue.main.autoSync {
            var ids = self.memberIds[conversationId] ?? []
            if !ids.contains(userId) {
                ids.append(userId)
                self.memberIds[conversationId] = ids
                let userInfo: [String: Any] = [
                    Self.UserInfoKey.conversationId: conversationId,
                    Self.UserInfoKey.userIds: ids
                ]
                NotificationCenter.default.post(name: Self.membersDidChangeNotification, object: self, userInfo: userInfo)
            }
            self.beginPolling(forConversationWith: conversationId)
        }
    }
    
    func removeMember(with userId: String, fromConversationWith conversationId: String) {
        Queue.main.autoSync {
            guard var members = self.memberIds[conversationId] else {
                return
            }
            Logger.call.info(category: "GroupCallMembersManager", message: "Remove member: \(userId), from: \(conversationId)")
            let countBefore = members.count
            members.removeAll(where: { $0 == userId })
            if members.count != countBefore {
                self.memberIds[conversationId] = members
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
    }
    
}

// MARK: - Polling
extension GroupCallMembersManager {
    
    private func beginPolling(forConversationWith conversationId: String) {
        assert(Thread.isMainThread)
        let key = conversationId as NSString
        guard self.pollingTimers.object(forKey: key) == nil else {
            return
        }
        let timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] (timer) in
            guard let self = self else {
                Logger.call.info(category: "PeerPolling", message: "manager of \(conversationId) is nil out")
                timer.invalidate()
                return
            }
            self.queue.async {
                guard let peers = self.messenger.requestPeers(forConversationWith: conversationId) else {
                    Logger.call.info(category: "PeerPolling", message: "Peer request failed. cid: \(conversationId)")
                    return
                }
                let remoteUserIds = Set(peers.map(\.userId))
                Logger.call.info(category: "PeerPolling", message: "cid: \(conversationId), remote id: \(remoteUserIds)")
                var localUserIds = self.memberIds[conversationId] ?? []
                Logger.call.info(category: "PeerPolling", message: "cid: \(conversationId), local id: \(localUserIds)")
                localUserIds = localUserIds.filter(remoteUserIds.contains)
                self.memberIds[conversationId] = localUserIds
                if localUserIds.isEmpty {
                    timer.invalidate()
                    Logger.call.info(category: "PeerPolling", message: "Member polling for \(conversationId) ends")
                }
                let userInfo: [String: Any] = [
                    Self.UserInfoKey.conversationId: conversationId,
                    Self.UserInfoKey.userIds: localUserIds
                ]
                NotificationCenter.default.post(onMainThread: Self.membersDidChangeNotification,
                                                object: self,
                                                userInfo: userInfo)
            }
        }
        pollingTimers.setObject(timer, forKey: key)
        Logger.call.info(category: "PeerPolling", message: "Begin polling members for \(conversationId)")
    }
    
    private func endPolling(forConversationWith id: String) {
        assert(Thread.isMainThread)
        guard let timer = pollingTimers.object(forKey: id as NSString) else {
            return
        }
        timer.invalidate()
        Logger.call.info(category: "PeerPolling", message: "End polling members for \(id)")
    }
    
}
