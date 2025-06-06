import Foundation
import MixinServices

struct DeviceTransferExpiredMessage {
    
    let messageId: String
    let expireIn: Int64
    var expireAt: Int64?
    
    init(expiredMessage: ExpiredMessage) {
        messageId = expiredMessage.messageId
        expireIn = expiredMessage.expireIn
        expireAt = expiredMessage.expireAt
    }
    
    func toExpiredMessage() -> ExpiredMessage {
        ExpiredMessage(messageId: messageId,
                       expireIn: expireIn,
                       expireAt: expireAt)
    }
    
}

extension DeviceTransferExpiredMessage: DeviceTransferRecord {
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case expireIn = "expire_in"
        case expireAt = "expire_at"
    }
    
}
