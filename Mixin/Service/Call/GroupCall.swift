import Foundation
import WebRTC
import MixinServices

class GroupCall: Call {
    
    let conversation: ConversationItem
    let conversationId: String
    let conversationName: String
    let membersDataSource: GroupCallMemberDataSource
    
    private(set) var members: [UserItem]
    
    var trackId: String?
    var inviterUserId: String?
    
    // invite after group call is connected
    private var pendingInvitingMembers: [UserItem]?
    
    // Key is user ID
    private var invitationTimers = NSMapTable<NSString, Timer>(keyOptions: .copyIn, valueOptions: .weakMemory)
    
    init(uuid: UUID, isOutgoing: Bool, conversation: ConversationItem, members: [UserItem], invitingMembers: [UserItem]) {
        self.conversation = conversation
        self.conversationId = conversation.conversationId
        self.conversationName = conversation.getConversationName()
        let allMembers = members + invitingMembers
        self.members = allMembers
        let invitingMemberUserIds = Set(invitingMembers.map(\.userId))
        self.membersDataSource = GroupCallMemberDataSource(members: allMembers,
                                                           invitingMemberUserIds: invitingMemberUserIds)
        self.pendingInvitingMembers = invitingMembers
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
    
    func invite(members: [UserItem]) {
        let filtered = members.filter { (member) -> Bool in
            !self.members.contains(where: { member.userId == $0.userId })
        }
        guard !filtered.isEmpty else {
            return
        }
        self.members.append(contentsOf: filtered)
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
        if !members.contains(where: { $0.userId == id }) {
            members.append(member)
        }
        DispatchQueue.main.async {
            self.membersDataSource.reportMemberDidConnected(member)
        }
    }
    
    func reportMemberWithIdDidDisconnected(_ id: String) {
        if let timer = invitationTimers.object(forKey: id as NSString) {
            timer.invalidate()
        }
        if let index = members.firstIndex(where: { $0.userId == id }) {
            members.remove(at: index)
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
                    if let self = self {
                        self.members.removeAll(where: { $0.userId == id })
                        DispatchQueue.main.async {
                            self.membersDataSource.reportMemberWithIdDidDisconnected(id)
                        }
                    }
                }
            }
            invitationTimers.setObject(timer, forKey: key)
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
}
