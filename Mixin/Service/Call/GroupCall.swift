import Foundation
import WebRTC
import MixinServices

class GroupCall: Call {
    
    static let maxNumberOfMembers = 256
    
    let conversation: ConversationItem
    let conversationName: String
    let membersDataSource: GroupCallMemberDataSource
    
    var frameKey: Data?
    var trackId: String?
    var inviters = [UserItem]()
    
    // invite after group call is connected
    private var pendingInvitingMembers: [UserItem]?
    
    private weak var speakingTimer: Timer?
    
    private var hasBegunConnecting: Bool {
        status != .incoming && status != .outgoing
    }
    
    override var description: String {
        "<GroupCall: uuid: \(uuidString), isOutgoing: \(isOutgoing), status: \(status.debugDescription), conversationId: \(conversationId), connectedDate: \(connectedDate?.description ?? "(never)"), trackId: \(trackId ?? "(null)"), inviters: \(inviters.map(\.fullName)), pendingInvitingMembers: \(pendingInvitingMembers?.map(\.fullName).debugDescription ?? "(null)")>"
    }
    
    override var status: Call.Status {
        didSet {
            if status == .connected {
                DispatchQueue.main.async {
                    guard self.speakingTimer == nil else {
                        return
                    }
                    self.speakingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
                        self?.rtcClient.audioLevels(completion: { levels in
                            self?.membersDataSource.report(audioLevels: levels)
                        })
                    })
                }
            } else {
                DispatchQueue.main.async {
                    self.speakingTimer?.invalidate()
                }
            }
        }
    }
    
    var localizedName: String {
        if inviters.isEmpty || hasBegunConnecting {
            return conversationName
        } else {
            return inviters.map(\.fullName).joined(separator: ", ")
        }
    }
    
    init(uuid: UUID, isOutgoing: Bool, conversation: ConversationItem, members: [UserItem], invitingMembers: [UserItem], rtcClient: WebRTCClient) {
        self.conversation = conversation
        self.conversationName = conversation.getConversationName()
        let conversationId = conversation.conversationId
        self.membersDataSource = GroupCallMemberDataSource(conversationId: conversationId,
                                                           members: members + invitingMembers,
                                                           invitingMemberUserIds: Set(invitingMembers.map(\.userId)))
        self.pendingInvitingMembers = invitingMembers
        super.init(uuid: uuid, conversationId: conversationId, isOutgoing: isOutgoing, rtcClient: rtcClient)
        CallService.shared.membersManager.beginPolling(forConversationWith: conversationId)
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
        assert(!userIds.isEmpty)
        let invitation = KrakenRequest(callUUID: uuid,
                                       conversationId: conversationId,
                                       trackId: trackId,
                                       action: .invite(recipients: userIds))
        KrakenMessageRetriever.shared.request(invitation, completion: nil)
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
