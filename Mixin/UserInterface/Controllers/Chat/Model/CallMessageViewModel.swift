import UIKit
import MixinServices

class CallMessageViewModel: IconPrefixedTextMessageViewModel {
    
    override var rawContent: String {
        let isRemote = message.userId != myUserId
        switch message.category {
        case MessageCategory.WEBRTC_AUDIO_CANCEL.rawValue:
            return isRemote ? R.string.localizable.canceled_by_caller() : R.string.localizable.canceled()
        case MessageCategory.WEBRTC_AUDIO_DECLINE.rawValue:
            return isRemote ? R.string.localizable.declined() : R.string.localizable.call_declined()
        case MessageCategory.WEBRTC_AUDIO_BUSY.rawValue:
            return isRemote ? R.string.localizable.line_busy() : R.string.localizable.line_busy_remote()
        case MessageCategory.WEBRTC_AUDIO_FAILED.rawValue:
            return R.string.localizable.call_failed()
        case MessageCategory.WEBRTC_AUDIO_END.rawValue:
            let mediaDuration = Double(message.mediaDuration ?? 0) / millisecondsPerSecond
            let duration = CallDurationFormatter.string(from: mediaDuration) ?? "0"
            return R.string.localizable.chat_call_duration(duration)
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
