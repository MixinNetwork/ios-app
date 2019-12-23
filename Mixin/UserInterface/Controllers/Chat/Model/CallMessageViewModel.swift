import UIKit
import MixinServices

class CallMessageViewModel: IconPrefixedTextMessageViewModel {
    
    override var rawContent: String {
        let isRemote = message.userId != myUserId
        switch message.category {
        case MessageCategory.WEBRTC_AUDIO_CANCEL.rawValue:
            return isRemote ? Localized.CHAT_MESSAGE_CALL_REMOTE_CANCELLED : Localized.CHAT_MESSAGE_CALL_CANCELLED
        case MessageCategory.WEBRTC_AUDIO_DECLINE.rawValue:
            return isRemote ? Localized.CHAT_MESSAGE_CALL_DECLINED : Localized.CHAT_MESSAGE_CALL_REMOTE_DECLINED
        case MessageCategory.WEBRTC_AUDIO_BUSY.rawValue:
            return isRemote ? Localized.CHAT_MESSAGE_CALL_BUSY : Localized.CHAT_MESSAGE_CALL_REMOTE_BUSY
        case MessageCategory.WEBRTC_AUDIO_FAILED.rawValue:
            return Localized.CHAT_MESSAGE_CALL_FAILED
        case MessageCategory.WEBRTC_AUDIO_END.rawValue:
            let mediaDuration = Double(message.mediaDuration ?? 0) / millisecondsPerSecond
            let duration = mediaDurationFormatter.string(from: mediaDuration) ?? "0"
            return Localized.CHAT_MESSAGE_CALL_DURATION(duration: duration)
        default:
            return ""
        }
    }
    
    override var showStatusImage: Bool {
        return false
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        if style.contains(.received) {
            prefixImage = R.image.call.ic_message_prefix_received()
        } else {
            prefixImage = R.image.call.ic_message_prefix_sent()
        }
    }
    
}
