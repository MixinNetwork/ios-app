import Foundation
import MixinServices

class CallManager: CallMessageCoordinator {
    
    static let shared = CallManager()
    
    var hasActiveCall: Bool {
        false
    }
    
    func handleIncomingBlazeMessageData(_ data: BlazeMessageData) {
        guard data.category == MessageCategory.WEBRTC_AUDIO_CANCEL.rawValue else {
            return
        }
        guard let user = UserDAO.shared.getUser(userId: data.userId) else {
            return
        }
        let conversationId = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: user.userId)
        let msg = Message.createWebRTCMessage(messageId: data.quoteMessageId,
                                              conversationId: conversationId,
                                              userId: user.userId,
                                              category: .WEBRTC_AUDIO_CANCEL,
                                              mediaDuration: 0,
                                              status: .DELIVERED)
        MessageDAO.shared.insertMessage(message: msg, messageSource: "")
    }
    
}
