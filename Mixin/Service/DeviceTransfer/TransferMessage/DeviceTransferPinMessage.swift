import Foundation
import MixinServices

struct DeviceTransferPinMessage {
    
    let messageId: String
    let conversationId: String
    let createdAt: String
    
    init(pinMessage: PinMessage) {
        messageId = pinMessage.messageId
        conversationId = pinMessage.conversationId
        createdAt = pinMessage.createdAt
    }
    
    func toPinMessage() -> PinMessage {
        PinMessage(messageId: messageId,
                   conversationId: conversationId,
                   createdAt: createdAt)
    }
    
}

extension DeviceTransferPinMessage: DeviceTransferRecord {
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case conversationId = "conversation_id"
        case createdAt = "created_at"
    }
    
}
