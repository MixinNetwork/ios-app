import Foundation
import MixinServices

class CallMessageSaver {
    
    static let shared = CallMessageSaver()
    
}

extension CallMessageSaver: CallMessageCoordinator {
    
    func shouldSendRtcBlazeMessage(with category: MessageCategory) -> Bool {
        true
    }
    
    func handleIncomingBlazeMessageData(_ data: BlazeMessageData) {
        if data.category == MessageCategory.WEBRTC_AUDIO_CANCEL.rawValue {
            let msg = Message.createWebRTCMessage(messageId: data.quoteMessageId,
                                                  conversationId: data.conversationId,
                                                  userId: data.userId,
                                                  category: .WEBRTC_AUDIO_CANCEL,
                                                  mediaDuration: 0,
                                                  status: .DELIVERED)
            MessageDAO.shared.insertMessage(message: msg, messageSource: "")
        } else {
            let job = Job(pendingWebRTCMessage: data)
            UserDatabase.current.save(job)
        }
    }
    
}
