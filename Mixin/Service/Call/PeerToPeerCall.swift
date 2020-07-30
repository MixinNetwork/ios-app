import Foundation
import MixinServices

class PeerToPeerCall: Call {
    
    let remoteUserId: String
    let remoteUsername: String
    
    var remoteUser: UserItem?
    var hasReceivedRemoteAnswer = false
    
    override var description: String {
        "<PeerToPeerCall: uuid: \(uuidString), isOutgoing: \(isOutgoing), status: \(status.debugDescription), conversationId: \(conversationId), connectedDate: \(connectedDate?.description ?? "(never)"), remoteUsername: \(remoteUsername), hasReceivedRemoteAnswer: \(hasReceivedRemoteAnswer))>"
    }
    
    init(uuid: UUID, isOutgoing: Bool, remoteUserId: String, remoteUsername: String) {
        self.remoteUserId = remoteUserId
        self.remoteUsername = remoteUsername
        let conversationId = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: remoteUserId)
        super.init(uuid: uuid, conversationId: conversationId, isOutgoing: isOutgoing)
    }
    
    convenience init(uuid: UUID, isOutgoing: Bool, remoteUser: UserItem) {
        self.init(uuid: uuid,
                  isOutgoing: isOutgoing,
                  remoteUserId: remoteUser.userId,
                  remoteUsername: remoteUser.fullName)
        self.remoteUser = remoteUser
    }
    
}
