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
    
    init(uuid: UUID, isOutgoing: Bool, remoteUserId: String, remoteUsername: String, rtcClient: WebRTCClient) {
        self.remoteUserId = remoteUserId
        self.remoteUsername = remoteUsername
        let conversationId = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: remoteUserId)
        super.init(uuid: uuid, conversationId: conversationId, isOutgoing: isOutgoing, rtcClient: rtcClient)
    }
    
    convenience init(uuid: UUID, isOutgoing: Bool, remoteUser: UserItem, rtcClient: WebRTCClient) {
        self.init(uuid: uuid,
                  isOutgoing: isOutgoing,
                  remoteUserId: remoteUser.userId,
                  remoteUsername: remoteUser.fullName,
                  rtcClient: rtcClient)
        self.remoteUser = remoteUser
    }
    
}
