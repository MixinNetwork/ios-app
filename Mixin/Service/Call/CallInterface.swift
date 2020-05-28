import Foundation
import CallKit

typealias CallInterfaceCompletion = (Error?) -> Void

protocol CallInterface {
    
    func requestStartCall(uuid: UUID, handle: CallHandle, completion: @escaping CallInterfaceCompletion)
    func requestAnswerCall(uuid: UUID)
    func requestEndCall(uuid: UUID, completion: @escaping CallInterfaceCompletion)
    func requestSetMute(uuid: UUID, muted: Bool, completion: @escaping CallInterfaceCompletion)
    func reportNewIncomingCall(_ call: Call, completion: @escaping CallInterfaceCompletion)
    func reportCall(uuid: UUID, endedByReason reason: CXCallEndedReason)
    func reportOutgoingCallStartedConnecting(uuid: UUID)
    func reportOutgoingCall(uuid: UUID, connectedAtDate date: Date)
    func reportIncomingCall(uuid: UUID, connectedAtDate date: Date)
    
}
