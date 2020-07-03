import Foundation
import WebRTC
import MixinServices

class GroupCall: Call {
    
    static let maxNumberOfMembers = 16
    
    let conversation: ConversationItem
    let conversationName: String
    let membersDataSource: GroupCallMemberDataSource
    
    override var debugDescription: String {
        "<GroupCall: uuid: \(uuidString), isOutgoing: \(isOutgoing), status: \(status.debugDescription), conversationId: \(conversationId), trackId: \(trackId ?? "(null)"), inviterUserId: \(inviterUserId ?? "(null)"), pendingInvitingMembers: \(pendingInvitingMembers?.map(\.fullName).debugDescription ?? "(null)")>"
    }
    
    var trackId: String?
    var inviterUserId: String?
    
    // invite after group call is connected
    private var pendingInvitingMembers: [UserItem]?
    
    // Key is user ID
    private var invitationTimers = NSMapTable<NSString, Timer>(keyOptions: .copyIn, valueOptions: .weakMemory)
    
    init(uuid: UUID, isOutgoing: Bool, conversation: ConversationItem, members: [UserItem], invitingMembers: [UserItem]) {
        self.conversation = conversation
        self.conversationName = conversation.getConversationName()
        let conversationId = conversation.conversationId
        self.membersDataSource = GroupCallMemberDataSource(conversationId: conversationId,
                                                           members: members + invitingMembers,
                                                           invitingMemberUserIds: Set(invitingMembers.map(\.userId)))
        self.pendingInvitingMembers = invitingMembers
        super.init(uuid: uuid, conversationId: conversationId, isOutgoing: isOutgoing)
        DispatchQueue.main.async {
            CallService.shared.membersManager.beginPolling(forConversationWith: conversation.conversationId)
        }
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
        let conversationId = self.conversationId
        DispatchQueue.main.async {
            CallService.shared.membersManager.endPolling(forConversationWith: conversationId)
        }
    }
    
    func invite(members: [UserItem]) {
        let inCallMembers = CallService.shared.membersManager.members(inConversationWith: conversationId)
        let inCallUserIds = Set(inCallMembers.map(\.userId))
        let filtered = members.filter { (member) -> Bool in
            !inCallUserIds.contains(member.userId)
        }
        guard !filtered.isEmpty else {
            return
        }
        inviteWithoutFiltering(members: filtered)
    }
    
    func invitePendingUsers() {
        guard let members = pendingInvitingMembers else {
            return
        }
        pendingInvitingMembers = nil
        inviteWithoutFiltering(members: members)
    }
    
    func reportMemberWithIdDidConnected(_ id: String) {
        if let timer = invitationTimers.object(forKey: id as NSString) {
            timer.invalidate()
        }
        guard let member = UserDAO.shared.getUser(userId: id) else {
            return
        }
        DispatchQueue.main.async {
            self.membersDataSource.reportMemberDidConnected(member)
        }
    }
    
    func reportMemberWithIdDidDisconnected(_ id: String) {
        if let timer = invitationTimers.object(forKey: id as NSString) {
            timer.invalidate()
        }
        DispatchQueue.main.async {
            self.membersDataSource.reportMemberWithIdDidDisconnected(id)
        }
    }
    
    private func inviteWithoutFiltering(members: [UserItem]) {
        guard let trackId = trackId else {
            assertionFailure()
            return
        }
        DispatchQueue.main.async {
            self.membersDataSource.reportStartInviting(members)
        }
        let conversationId = self.conversationId
        let userIds = members.map(\.userId)
        let invitation = KrakenRequest(conversationId: conversationId,
                                       trackId: trackId,
                                       action: .invite(recipients: userIds))
        SendMessageService.shared.send(krakenRequest: invitation) // TODO: Some of the recipients may fail?
        for id in userIds {
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
                    DispatchQueue.main.async {
                        self?.membersDataSource.reportMemberWithIdDidDisconnected(id)
                    }
                }
            }
            invitationTimers.setObject(timer, forKey: key)
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
}
