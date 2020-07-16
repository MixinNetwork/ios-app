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
        let invitation = KrakenRequest(callUUID: uuid,
                                       conversationId: conversationId,
                                       trackId: trackId,
                                       action: .invite(recipients: userIds))
        SendMessageService.shared.send(krakenRequest: invitation,
                                       shouldRetryOnError: CallService.shared.shouldRetryKrakenRequest(_:_:_:))
    }
    
    func invitePendingUsers() {
        guard let members = pendingInvitingMembers else {
            return
        }
        pendingInvitingMembers = nil
        if !members.isEmpty {
            invite(members: members)
        }
    }
    
    func reportMemberWithIdDidConnected(_ id: String) {
        guard let member = UserDAO.shared.getUser(userId: id) else {
            return
        }
        DispatchQueue.main.async {
            self.membersDataSource.reportMemberDidConnected(member)
        }
    }
    
    func reportMemberWithIdDidDisconnected(_ id: String) {
        DispatchQueue.main.async {
            self.membersDataSource.reportMemberWithIdDidDisconnected(id)
        }
    }
    
}
