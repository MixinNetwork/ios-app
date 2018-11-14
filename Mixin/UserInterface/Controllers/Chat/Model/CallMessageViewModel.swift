import UIKit

class CallMessageViewModel: TextMessageViewModel {
    
    static let prefixImage = UIImage(named: "Call/ic_message_prefix")!
    static let prefixSize = prefixImage.size
    static let prefixInset = UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 6)
    
    internal(set) var prefixFrame = CGRect.zero
    
    override var rawContent: String {
        let isRemote = message.userId != AccountAPI.shared.accountUserId
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
    
    override var contentAdditionalLeadingMargin: CGFloat {
        return CallMessageViewModel.prefixSize.width + CallMessageViewModel.prefixInset.horizontal
    }
    
    override func didSetStyle() {
        super.didSetStyle()
        prefixFrame = CGRect(x: contentLabelFrame.origin.x + CallMessageViewModel.prefixInset.left,
                             y: contentLabelFrame.origin.y,
                             width: CallMessageViewModel.prefixSize.width,
                             height: contentLabelFrame.height)
        contentLabelFrame.origin.x += (prefixFrame.width + CallMessageViewModel.prefixInset.horizontal)
    }
    
}
