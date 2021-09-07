import Foundation
import MixinServices

struct VisiblePinMessage: Codable {
    
    let messageId: String
    let pinnedMessageId: String
    
}

extension AppGroupUserDefaults.User {
    
    static func visiblePinMessage(for conversationId: String) -> VisiblePinMessage? {
        guard let data = visiblePinMessagesData[conversationId] else {
            return nil
        }
        return try? JSONDecoder.default.decode(VisiblePinMessage.self, from: data)
    }
    
    static func setVisiblePinMessage(_ message: VisiblePinMessage?, for conversationId: String) {
        visiblePinMessagesData[conversationId] = try? JSONEncoder.default.encode(message)
    }
    
}
