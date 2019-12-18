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
}
