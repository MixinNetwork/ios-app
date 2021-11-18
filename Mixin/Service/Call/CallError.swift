import Foundation
import MixinServices

enum CallError: Error {
    
    case busy
    case microphonePermissionDenied
    
    case missingCall(uuid: UUID)
    case invalidState(description: String)
    case missingUser(userId: String)
    case inconsistentCallStarted
    case inconsistentCallAnswered
    
    case offerConstruction(Error?)
    case setRemoteSdp(Error)
    case answerConstruction(Error?)
    
    case networkFailure
    case invalidKrakenResponse
    case roomFull
    case peerNotFound
    case peerClosed
    case trackNotFound
    
    var alertContent: String {
        switch self {
        case .busy:
            return R.string.localizable.call_hint_on_another_call()
        case .networkFailure:
            return R.string.localizable.call_no_network()
        case .microphonePermissionDenied:
            return R.string.localizable.call_no_microphone_permission()
        case .roomFull:
            return R.string.localizable.error_room_full()
        case .peerNotFound:
            return R.string.localizable.call_remote_error("5002001")
        case .peerClosed:
            return R.string.localizable.call_remote_error("5002002")
        case .trackNotFound:
            return R.string.localizable.call_remote_error("5002003")
        default:
            return R.string.localizable.chat_message_call_failed()
        }
    }
    
}
