import Foundation

enum CallError: Error {
    case busy
    case invalidUUID(uuid: String)
    case invalidSdp(sdp: String?)
    case missingUser(userId: String)
    case networkFailure
    case microphonePermissionDenied
}

class Call {
    
    let uuid: UUID
    let opponentUser: UserItem
    let isOutgoing: Bool
    
    var connectedDate: Date?
    var hasReceivedRemoteAnswer = false
    
    private(set) lazy var uuidString = uuid.uuidString.lowercased() // Message Id from offer message
    private(set) lazy var conversationId = ConversationDAO.shared.makeConversationId(userId: AccountAPI.shared.accountUserId, ownerUserId: opponentUser.userId)
    private(set) lazy var raisedByUserId = isOutgoing ? AccountAPI.shared.accountUserId : opponentUser.userId
    
    init(uuid: UUID, opponentUser: UserItem, isOutgoing: Bool) {
        self.uuid = uuid
        self.opponentUser = opponentUser
        self.isOutgoing = isOutgoing
    }
    
}
