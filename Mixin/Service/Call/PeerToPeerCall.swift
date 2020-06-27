import Foundation
import MixinServices

class PeerToPeerCall: Call {
    
    let remoteUserId: String
    let remoteUsername: String
    
    var remoteUser: UserItem?
    var hasReceivedRemoteAnswer = false
    
    private(set) lazy var conversationId = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: remoteUserId)
    
    init(uuid: UUID, isOutgoing: Bool, remoteUserId: String, remoteUsername: String) {
        self.remoteUserId = remoteUserId
        self.remoteUsername = remoteUsername
        super.init(uuid: uuid, isOutgoing: isOutgoing)
    }
    
    convenience init(uuid: UUID, isOutgoing: Bool, remoteUser: UserItem) {
        self.init(uuid: uuid,
                  isOutgoing: isOutgoing,
                  remoteUserId: remoteUser.userId,
                  remoteUsername: remoteUser.fullName)
        self.remoteUser = remoteUser
    }
    
}
