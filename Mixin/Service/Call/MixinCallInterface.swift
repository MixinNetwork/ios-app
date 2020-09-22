import UIKit
import AVFoundation
import UserNotifications
import CallKit
import WebRTC
import MixinServices

class MixinCallInterface: NSObject {
    
    private let callObserver = CXCallObserver()
    private let vibrator = Vibrator()
    
    private unowned let service: CallService
    
    private var pendingIncomingUuid: UUID?
    
    required init(service: CallService) {
        self.service = service
        super.init()
        self.callObserver.setDelegate(self, queue: service.queue)
    }
    
    deinit {
        vibrator.stop()
    }
    
}

extension MixinCallInterface: CallInterface {
    
    func requestStartCall(uuid: UUID, handle: CXHandle, playOutgoingRingtone: Bool, completion: @escaping CallInterfaceCompletion) {
        guard WebSocketService.shared.isConnected else {
            completion(CallError.networkFailure)
            return
        }
        let isLineIdle: Bool
        if let call = service.activeCall {
            isLineIdle = call.uuid == uuid
        } else {
            isLineIdle = callObserver.calls.isEmpty
        }
        guard isLineIdle else {
            completion(CallError.busy)
            return
        }
        self.service.startCall(uuid: uuid, handle: handle, completion: { success in
            guard success else {
                return
            }
            if playOutgoingRingtone {
                try? AVAudioSession.sharedInstance().setActive(true, options: [])
                self.service.ringtonePlayer.play(ringtone: .outgoing)
            }
        })
        completion(nil)
    }
    
    func requestAnswerCall(uuid: UUID) {
        vibrator.stop()
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        service.answerCall(uuid: uuid, completion: nil)
    }
    
    func requestEndCall(uuid: UUID, completion: @escaping CallInterfaceCompletion) {
        vibrator.stop()
        if uuid == pendingIncomingUuid {
            pendingIncomingUuid = nil
        }
        UNUserNotificationCenter.current().removeNotifications(withIdentifiers: [uuid.uuidString])
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        service.endCall(uuid: uuid)
        completion(nil)
    }
    
    func requestSetMute(uuid: UUID, muted: Bool, completion: @escaping CallInterfaceCompletion) {
        service.isMuted = muted
        completion(nil)
    }
    
    func reportIncomingCall(_ call: Call, completion: @escaping CallInterfaceCompletion) {
        guard service.activeCall == nil && callObserver.calls.isEmpty else {
            completion(CallError.busy)
            return
        }
        AVAudioSession.sharedInstance().requestRecordPermission { (isGranted) in
            self.service.queue.async {
                guard isGranted else {
                    completion(CallError.microphonePermissionDenied)
                    return
                }
                guard self.pendingIncomingUuid == nil else {
                    completion(CallError.busy)
                    return
                }
                DispatchQueue.main.sync {
                    if UIApplication.shared.applicationState == .active {
                        self.service.ringtonePlayer.play(ringtone: .incoming)
                        self.vibrator.start()
                    } else {
                        let manager = NotificationManager.shared
                        if let call = call as? PeerToPeerCall {
                            manager.requestCallNotification(id: call.uuidString,
                                                            name: call.remoteUsername)
                        } else if let call = call as? GroupCall {
                            manager.requestCallNotification(id: call.uuidString,
                                                            name: call.conversationName)
                        }
                        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                            var authorizedStatus: [UNAuthorizationStatus] = [.authorized]
                            if #available(iOS 12.0, *) {
                                authorizedStatus.append(.provisional)
                            }
                            if authorizedStatus.contains(settings.authorizationStatus) {
                                self.vibrator.start()
                            }
                        }
                    }
                    call.status = .incoming
                    self.service.showCallingInterface(call: call)
                    UIApplication.shared.isIdleTimerDisabled = true
                }
                self.pendingIncomingUuid = call.uuid
                completion(nil)
            }
        }
    }
    
    func reportCall(uuid: UUID, endedByReason reason: CXCallEndedReason) {
        vibrator.stop()
        if uuid == pendingIncomingUuid {
            pendingIncomingUuid = nil
        }
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        UNUserNotificationCenter.current().removeNotifications(withIdentifiers: [uuid.uuidString])
    }
    
    func reportOutgoingCallStartedConnecting(uuid: UUID) {
        if uuid == pendingIncomingUuid {
            pendingIncomingUuid = nil
        }
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    func reportOutgoingCall(uuid: UUID, connectedAtDate date: Date) {
        
    }
    
    func reportIncomingCall(_ call: Call, connectedAtDate date: Date) {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
}

extension MixinCallInterface: CXCallObserverDelegate {
    
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        if call.hasConnected, !service.hasCall(with: call.uuid) {
            service.requestEndCall()
        }
    }
    
}
