import Foundation
import MixinServices

class Call {
    
    let uuid: UUID // Message ID of offer message
    let opponentUserId: String
    let opponentUsername: String
    let isOutgoing: Bool
    
    var opponentUser: UserItem?
    var connectedDate: Date?
    var hasReceivedRemoteAnswer = false
    
    private(set) lazy var uuidString = uuid.uuidString.lowercased()
    private(set) lazy var conversationId = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: opponentUserId)
    private(set) lazy var raisedByUserId = isOutgoing ? myUserId : opponentUserId
    
    init(uuid: UUID, opponentUserId: String, opponentUsername: String, isOutgoing: Bool) {
        self.uuid = uuid
        self.opponentUserId = opponentUserId
        self.opponentUsername = opponentUsername
        self.isOutgoing = isOutgoing
    }
    
    convenience init(uuid: UUID, opponentUser: UserItem, isOutgoing: Bool) {
        self.init(uuid: uuid,
                  opponentUserId: opponentUser.userId,
                  opponentUsername: opponentUser.fullName,
                  isOutgoing: isOutgoing)
        self.opponentUser = opponentUser
    }
    
}
