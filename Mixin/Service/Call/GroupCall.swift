import Foundation
import WebRTC
import MixinServices

class GroupCall: Call {
    
    let conversation: ConversationItem
    let conversationId: String
    let conversationName: String
    let membersDataSource: GroupCallMemberDataSource
    
    private(set) var connectedMembers: [UserItem]
    private(set) var connectingMembers: [UserItem]
    
    var trackId: String?
    var inviterUserId: String?
    
    // invite after group call is connected
    private var pendingInvitingUsers: [UserItem]?
    
    // Key is user ID
    private var invitationTimers = NSMapTable<NSString, Timer>(keyOptions: .copyIn, valueOptions: .weakMemory)
    
    init(uuid: UUID, isOutgoing: Bool, conversation: ConversationItem, connectedMembers: [UserItem], connectingMembers: [UserItem], invitingMembers: [UserItem]) {
        self.conversation = conversation
        self.conversationId = conversation.conversationId
        self.conversationName = conversation.getConversationName()
        self.connectedMembers = connectedMembers
        self.connectingMembers = connectingMembers
        self.membersDataSource = GroupCallMemberDataSource(connected: connectedMembers,
                                                           connecting: connectingMembers + invitingMembers)
        self.pendingInvitingUsers = invitingMembers
        super.init(uuid: uuid, isOutgoing: isOutgoing)
    }
    
    deinit {
        let timers = self.invitationTimers
        CallService.shared.queue.async {
            guard let enumerator = timers.objectEnumerator() else {
                return
            }
            for case let timer as Timer in enumerator.allObjects {
                timer.fire()
                timer.invalidate()
            }
        }
    }
    
    func invite(users: [UserItem]) {
        guard let trackId = trackId else {
            assertionFailure()
            return
        }
        let filtered = users.filter { (user) -> Bool in
            !connectedMembers.contains(where: { user.userId == $0.userId })
                && !connectingMembers.contains(where: { user.userId == $0.userId })
        }
        guard !filtered.isEmpty else {
            return
        }
        let conversationId = self.conversationId
        let recipients = filtered.map(\.userId)
        let invitation = KrakenRequest(conversationId: conversationId,
                                       trackId: trackId,
                                       action: .invite(recipients: recipients))
        SendMessageService.shared.send(krakenRequest: invitation) // TODO: Some of the recipients may fail?
        for id in recipients {
            let key = id as NSString
            if let timer = invitationTimers.object(forKey: id as NSString) {
                timer.invalidate()
            }
            let timer = Timer(timeInterval: callTimeoutInterval, repeats: false) { [weak self] (_) in
                CallService.shared.queue.async {
                    let cancel = KrakenRequest(conversationId: conversationId,
                                               trackId: trackId,
                                               action: .cancel(recipientId: id))
                    SendMessageService.shared.send(krakenRequest: cancel)
                    if let self = self {
                        self.connectingMembers.removeAll(where: { $0.userId == id })
                        DispatchQueue.main.async {
                            self.membersDataSource.reportMemberWithIdDidDisconnected(id)
                        }
                    }
                }
            }
            invitationTimers.setObject(timer, forKey: key)
            RunLoop.main.add(timer, forMode: .common)
        }
        connectingMembers.append(contentsOf: filtered)
        DispatchQueue.main.async {
            self.membersDataSource.reportMembersStartedConnecting(filtered)
        }
    }
    
    func invitePendingUsers() {
        guard let users = pendingInvitingUsers else {
            return
        }
        pendingInvitingUsers = nil
        invite(users: users)
    }
    
    func reportMemberWithIdStartedConnecting(_ id: String) {
        if let timer = invitationTimers.object(forKey: id as NSString) {
            timer.invalidate()
        }
        guard let user = UserDAO.shared.getUser(userId: id) else {
            return
        }
        guard !connectingMembers.contains(where: { $0.userId == id }) else {
            return
        }
        connectingMembers.append(user)
        DispatchQueue.main.async {
            self.membersDataSource.reportMembersStartedConnecting([user])
        }
    }
    
    func reportMemberWithIdDidConnected(_ id: String) {
        if let timer = invitationTimers.object(forKey: id as NSString) {
            timer.invalidate()
        }
        guard let user = UserDAO.shared.getUser(userId: id) else {
            return
        }
        if !connectedMembers.contains(where: { $0.userId == id }) {
            connectedMembers.append(user)
        }
        if let index = connectingMembers.firstIndex(where: { $0.userId == id }) {
            connectingMembers.remove(at: index)
        }
        DispatchQueue.main.async {
            self.membersDataSource.reportMemberDidConnected(user)
        }
    }
    
    func reportMemberWithIdDidDisconnected(_ id: String) {
        if let timer = invitationTimers.object(forKey: id as NSString) {
            timer.invalidate()
        }
        if let index = connectedMembers.firstIndex(where: { $0.userId == id }) {
            connectedMembers.remove(at: index)
        }
        if let index = connectingMembers.firstIndex(where: { $0.userId == id }) {
            connectingMembers.remove(at: index)
        }
        DispatchQueue.main.async {
            self.membersDataSource.reportMemberWithIdDidDisconnected(id)
        }
    }
    
}
