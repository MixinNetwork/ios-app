import Foundation
import CallKit

typealias CallInterfaceCompletion = (Error?) -> Void

protocol CallInterface: NSObjectProtocol {
    
    func requestStartCall(uuid: UUID, handle: CXHandle, playOutgoingRingtone: Bool, completion: @escaping CallInterfaceCompletion)
    func requestAnswerCall(uuid: UUID)
    func requestEndCall(uuid: UUID, completion: @escaping CallInterfaceCompletion)
    func requestSetMute(uuid: UUID, muted: Bool, completion: @escaping CallInterfaceCompletion)
    
    // Implementation must call completion at some point, or the CallService will be waiting forever
    func reportIncomingCall(_ call: Call, completion: @escaping CallInterfaceCompletion)
    
    func reportCall(uuid: UUID, endedByReason reason: CXCallEndedReason)
    func reportOutgoingCallStartedConnecting(uuid: UUID)
    func reportOutgoingCall(uuid: UUID, connectedAtDate date: Date)
    func reportIncomingCall(_ call: Call, connectedAtDate date: Date)
    
}
