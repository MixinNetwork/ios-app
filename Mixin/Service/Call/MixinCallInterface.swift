import UIKit
import AVFoundation
import UserNotifications
import CallKit
import WebRTC
import MixinServices

class MixinCallInterface {
    
    private let callObserver = CXCallObserver()
    
    private unowned let service: CallService
    
    private lazy var vibrator = Vibrator()
    
    private var pendingIncomingUuid: UUID?
    
    required init(service: CallService) {
        self.service = service
    }
    
}

extension MixinCallInterface: CallInterface {
    
    func requestStartCall(uuid: UUID, handle: CallHandle, completion: @escaping CallInterfaceCompletion) {
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
            RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
                try? RTCAudioSession.sharedInstance().setActive(true)
                self.service.ringtonePlayer.play(ringtone: .outgoing)
            }
        })
        completion(nil)
    }
    
    func requestAnswerCall(uuid: UUID) {
        vibrator.stop()
        service.answerCall(uuid: uuid, completion: nil)
    }
    
    func requestEndCall(uuid: UUID, completion: @escaping CallInterfaceCompletion) {
        vibrator.stop()
        if uuid == pendingIncomingUuid {
            pendingIncomingUuid = nil
        }
        UNUserNotificationCenter.current().removeNotifications(withIdentifiers: [uuid.uuidString])
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
                if self.pendingIncomingUuid == nil {
                    DispatchQueue.main.sync {
                        if UIApplication.shared.applicationState == .active {
                            self.service.ringtonePlayer.play(ringtone: .incoming)
                            self.vibrator.start()
                        } else {
                            NotificationManager.shared.requestCallNotification(messageId: call.uuidString, callerName: call.remoteUsername)
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
                        if let user = call.remoteUser {
                            self.service.showCallingInterface(user: user,
                                                              status: .incoming)
                        } else {
                            self.service.showCallingInterface(userId: call.remoteUserId,
                                                              username: call.remoteUsername,
                                                              status: .incoming)
                        }
                    }
                    self.pendingIncomingUuid = call.uuid
                    completion(nil)
                } else {
                    completion(CallError.busy)
                }
            }
        }
    }
    
    func reportCall(uuid: UUID, endedByReason reason: CXCallEndedReason) {
        vibrator.stop()
        if uuid == pendingIncomingUuid {
            pendingIncomingUuid = nil
        }
        UNUserNotificationCenter.current().removeNotifications(withIdentifiers: [uuid.uuidString])
    }
    
    func reportOutgoingCallStartedConnecting(uuid: UUID) {
        if uuid == pendingIncomingUuid {
            pendingIncomingUuid = nil
        }
    }
    
    func reportOutgoingCall(uuid: UUID, connectedAtDate date: Date) {
        
    }
    
    func reportIncomingCall(uuid: UUID, connectedAtDate date: Date) {
        
    }
    
}
