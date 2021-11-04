import Foundation
import CallKit
import WebRTC
import MixinServices

class GeneralAdapter {
    
    private let callObserver = CXCallObserver()
    private let vibrator = Vibrator()
    private let ringtonePlayer = RingtonePlayer()
    
    private unowned let service: CallService
    
    private var displayAwakeningToken: DisplayAwakener.Token?
    
    required init(service: CallService) {
        self.service = service
    }
    
}

extension GeneralAdapter: CallAdapter {
    
    func requestStartCall(_ call: Call, completion: @escaping Call.Completion) {
        assert(Thread.isMainThread)
        guard !service.hasCall && callObserver.calls.isEmpty else {
            completion(CallError.busy)
            return
        }
        completion(nil)
        service.performStartCall(uuid: call.uuid) { error in
            guard error == nil else {
                return
            }
            RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
                let audioSession = RTCAudioSession.sharedInstance()
                try? audioSession.setActive(true)
                DispatchQueue.main.sync {
                    self.service.audioSessionDidActivated(audioSession.session)
                }
            }
        }
    }
    
    func requestAnswerCall(_ call: Call, completion: @escaping Call.Completion) {
        assert(Thread.isMainThread)
        ringtonePlayer.stop()
        if let token = displayAwakeningToken {
            DisplayAwakener.shared.release(token: token)
        }
        completion(nil)
        service.performAnswerCall(uuid: call.uuid) { error in
            guard error == nil else {
                return
            }
            RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
                RTCAudioSession.sharedInstance().isAudioEnabled = true
            }
        }
    }
    
    func requestEndCall(_ call: Call, completion: @escaping Call.Completion) {
        assert(Thread.isMainThread)
        ringtonePlayer.stop()
        if let token = displayAwakeningToken {
            DisplayAwakener.shared.release(token: token)
        }
        completion(nil)
        service.performEndCall(uuid: call.uuid) { error in
            
        }
    }
    
    func requestSetMute(_ call: Call, muted: Bool, completion: @escaping Call.Completion) {
        assert(Thread.isMainThread)
        let error = service.performSetMute(uuid: call.uuid, muted: muted)
        completion(error)
    }
    
    func reportNewIncomingCall(_ call: Call, completion: @escaping Call.Completion) {
        assert(Thread.isMainThread)
        AVAudioSession.sharedInstance().requestRecordPermission { (isGranted) in
            Queue.main.autoAsync {
                if isGranted {
                    if self.service.activeCall == nil && self.service.calls.count == 1 && self.service.calls[call.uuid] != nil {
                        self.ringtonePlayer.play(ringtone: .incoming)
                        self.service.showCallingInterface(call: call, animated: true)
                        self.displayAwakeningToken = DisplayAwakener.shared.retain()
                        completion(nil)
                    } else {
                        completion(CallError.busy)
                    }
                } else {
                    if UIApplication.shared.applicationState == .active {
                        self.service.alert(error: CallError.microphonePermissionDenied)
                    } else {
                        if let call = call as? PeerCall {
                            NotificationManager.shared.requestDeclinedCallNotification(username: call.remoteUsername, messageId: call.uuidString)
                        } else if call is GroupCall {
                            NotificationManager.shared.requestDeclinedGroupCallNotification(localizedName: call.localizedName, messageId: call.uuidString)
                        }
                    }
                    completion(CallError.microphonePermissionDenied)
                }
            }
        }
    }
    
    func reportCall(_ call: Call, callerNameUpdatedWith name: String) {
        
    }
    
    func reportOutgoingCallStartedConnecting(_ call: Call) {
        
    }
    
    func reportOutgoingCallConnected(_ call: Call) {
        RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
            RTCAudioSession.sharedInstance().isAudioEnabled = true
        }
    }
    
    func reportCall(_ call: Call, endedByReason reason: Call.EndedReason, side: Call.EndedSide) {
        if !service.hasCall {
            RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
                RTCAudioSession.sharedInstance().isAudioEnabled = false
            }
        }
    }
    
}
