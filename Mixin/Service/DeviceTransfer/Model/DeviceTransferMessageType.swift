import Foundation

enum DeviceTransferMessageType: String, Codable, CaseIterable {
    
    case conversation
    case participant = "participant"
    case user
    case app
    case asset
    case snapshot
    case sticker
    case pinMessage = "pin_message"
    case transcriptMessage = "transcript_message"
    case message
    case messageMention = "message_mention"
    case expiredMessage = "expired_message"
    case command
    case unknown
    
}
