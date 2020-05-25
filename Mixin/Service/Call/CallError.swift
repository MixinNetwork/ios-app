import Foundation

enum CallError: Error {
    
    case busy
    case invalidUUID(uuid: String)
    case invalidSdp(sdp: String?)
    case missingUser(userId: String)
    case networkFailure
    case microphonePermissionDenied
    
    case setRemoteSdp(Error)
    case answerConstruction(Error?)
    case setRemoteAnswer(Error)
    case clientFailure
    case sdpConstruction(Error?)
    case sdpSerialization(Error?)
    
    case invalidHandle
    
    var alertContent: String? {
        switch self {
        case .busy:
            return Localized.CALL_HINT_ON_ANOTHER_CALL
        case .networkFailure:
            return Localized.CALL_NO_NETWORK
        case .microphonePermissionDenied:
            return Localized.CALL_NO_MICROPHONE_PERMISSION
        default:
            return nil
        }
    }
    
}
