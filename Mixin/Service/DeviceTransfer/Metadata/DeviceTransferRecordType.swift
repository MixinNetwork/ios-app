import Foundation

enum DeviceTransferRecordType: String, Codable, CaseIterable {
    
    case conversation
    case participant = "participant"
    case user
    case app
    case asset
    case token = "token"
    case snapshot
    case safe_snapshot = "safe_snapshot"
    case sticker
    case pinMessage = "pin_message"
    case transcriptMessage = "transcript_message"
    case message
    case messageMention = "message_mention"
    case expiredMessage = "expired_message"
    
}
