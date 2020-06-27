import Foundation
import WebRTC
import MixinServices

protocol GroupCallMemberObserver: class {
    func groupCall(_ call: GroupCall, didAppendMember member: UserItem)
    func groupCall(_ call: GroupCall, didRemoveMemberAt index: Int)
    func groupCall(_ call: GroupCall, didUpdateMemberAt index: Int)
    func groupCallDidReplaceAllMembers(_ call: GroupCall)
}

class GroupCall: Call {
    
    let conversation: ConversationItem
    let conversationId: String
    let conversationName: String
    
    var trackId: String?
    var inviterUserId: String?
    var invitingUsers: [UserItem] = [] {
        didSet {
            members.append(contentsOf: invitingUsers)
        }
    }
    
    weak var membersObserver: GroupCallMemberObserver?
    
    private(set) var members = [UserItem]()
    private(set) var connectedMemberUserIds = Set<String>()
    
    init(uuid: UUID, isOutgoing: Bool, conversation: ConversationItem) {
        self.conversation = conversation
        self.conversationId = conversation.conversationId
        self.conversationName = conversation.getConversationName()
        if let account = LoginManager.shared.account {
            let user = UserItem.createUser(from: account)
            self.members = [user]
            connectedMemberUserIds = [user.userId]
        }
        super.init(uuid: uuid, isOutgoing: isOutgoing)
    }
    
    func replaceMembers(withConnectedMembers members: [UserItem]) {
        self.members = members
        connectedMemberUserIds = Set(members.map(\.userId))
        membersObserver?.groupCallDidReplaceAllMembers(self)
    }
    
    func appendMember(_ member: UserItem, isConnected: Bool) {
        if let index = members.firstIndex(where: { $0.userId == member.userId }) {
            updateMember(at: index, isConnected: isConnected)
        } else {
            members.append(member)
            if isConnected {
                connectedMemberUserIds.insert(member.userId)
            }
            membersObserver?.groupCall(self, didAppendMember: member)
        }
    }
    
    func removeMember(with userId: String) {
        connectedMemberUserIds.remove(userId)
        if let index = members.firstIndex(where: { $0.userId == userId }) {
            members.remove(at: index)
            membersObserver?.groupCall(self, didRemoveMemberAt: index)
        }
    }
    
    func updateMember(with userId: String, isConnected: Bool) {
        guard let index = members.firstIndex(where: { $0.userId == userId }) else {
            return
        }
        updateMember(at: index, isConnected: isConnected)
    }
    
    private func updateMember(at index: Int, isConnected: Bool) {
        let userId = members[index].userId
        if isConnected {
            let (inserted, _) = connectedMemberUserIds.insert(userId)
            if inserted {
                membersObserver?.groupCall(self, didUpdateMemberAt: index)
            }
        } else {
            if connectedMemberUserIds.remove(userId) != nil {
                membersObserver?.groupCall(self, didUpdateMemberAt: index)
            }
        }
    }
    
}
