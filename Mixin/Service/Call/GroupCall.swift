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
        CallService.shared.membersManager.beginPolling(forConversationWith: conversation.conversationId)
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
        CallService.shared.membersManager.endPolling(forConversationWith: conversationId)
    }
    
    func invite(members: [UserItem]) {
        guard let trackId = trackId else {
            assertionFailure()
            return
        }
        DispatchQueue.main.sync {
            self.membersDataSource.reportStartInviting(members)
        }
        let conversationId = self.conversationId
        let userIds = members.map(\.userId)
        let invitation = KrakenRequest(conversationId: conversationId,
                                       trackId: trackId,
                                       action: .invite(recipients: userIds))
        SendMessageService.shared.send(krakenRequest: invitation)
        for id in userIds {
            let key = id as NSString
            invitationTimers.object(forKey: key)?.invalidate()
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
    
    func invitePendingUsers() {
        guard let members = pendingInvitingMembers else {
            return
        }
        pendingInvitingMembers = nil
        invite(members: members)
    }
    
    func reportMemberWithIdDidConnected(_ id: String) {
        invitationTimers.object(forKey: id as NSString)?.invalidate()
        guard let member = UserDAO.shared.getUser(userId: id) else {
            return
        }
        DispatchQueue.main.async {
            self.membersDataSource.reportMemberDidConnected(member)
        }
    }
    
    func reportMemberWithIdDidDisconnected(_ id: String) {
        invitationTimers.object(forKey: id as NSString)?.invalidate()
        DispatchQueue.main.async {
            self.membersDataSource.reportMemberWithIdDidDisconnected(id)
        }
    }
    
}
