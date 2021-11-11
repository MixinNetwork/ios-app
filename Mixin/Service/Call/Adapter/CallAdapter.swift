import Foundation

protocol CallAdapter {
    
    func requestStartCall(_ call: Call, completion: @escaping Call.Completion)
    func requestAnswerCall(_ call: Call, completion: @escaping Call.Completion)
    func requestEndCall(_ call: Call, completion: @escaping Call.Completion)
    func requestSetMute(_ call: Call, muted: Bool, completion: @escaping Call.Completion)
    
    func reportNewIncomingCall(_ call: Call, completion: @escaping Call.Completion)
    func reportCall(_ call: Call, callerNameUpdatedWith name: String)
    func reportOutgoingCallStartedConnecting(_ call: Call)
    func reportOutgoingCallConnected(_ call: Call)
    func reportCall(_ call: Call, endedByReason reason: Call.EndedReason, side: Call.EndedSide)
    
}
