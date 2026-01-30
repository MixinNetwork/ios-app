import Foundation
import AVFoundation
import CallKit
import WebRTC
import MixinServices

// According to documentation of CXProvider:
// A VoIP app should create only one instance of CXProvider and store it for use globally
fileprivate let cxProvider: CXProvider = {
    let config = CXProviderConfiguration()
    config.ringtoneSound = R.file.callCaf.filename
    config.iconTemplateImageData = R.image.call.ic_mixin()?.pngData()
    config.maximumCallGroups = 1
    config.maximumCallsPerCallGroup = 1
    config.supportsVideo = false
    config.supportedHandleTypes = [.generic]
    config.includesCallsInRecents = false
    return CXProvider(configuration: config)
}()

class CallKitAdapter: NSObject {
    
    private unowned let service: CallService
    
    private let callController: CXCallController
    
    // According to documentation of [CXAction fulfill], it must be called from the
    // implementation of a CXProviderDelegate method, which means that any function
    // get called in those delegate methods should be synchornous. But that's
    // impossible for every WebRTC methods to be synchornous, for example
    // [RTCPeerConnection offerForConstraints:completionHandler:] is one of them.
    // Since there must be a semaphore somewhere, we chose to put that semaphore
    // here, blocking this queue from async function returns.
    private let queue = DispatchQueue(label: "one.mixin.messenger.CallKitAdapter")
    
    required init(service: CallService) {
        self.service = service
        self.callController = CXCallController(queue: .main)
        super.init()
        cxProvider.setDelegate(self, queue: queue)
    }
    
    @available(*, unavailable)
    override init() {
        fatalError()
    }
    
    func reportImmediateFailureCall() {
        let uuid = UUID()
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: "")
        update.localizedCallerName = ""
        cxProvider.reportNewIncomingCall(with: uuid, update: update) { error in
            if error == nil {
                cxProvider.reportCall(with: uuid, endedAt: nil, reason: .failed)
            }
        }
    }
    
}

extension CallKitAdapter: CallAdapter {
    
    func requestStartCall(_ call: Call, completion: @escaping Call.Completion) {
        let action = CXStartCallAction(call: call.uuid, handle: call.cxHandle)
        callController.requestTransaction(with: action, completion: completion)
    }
    
    func requestAnswerCall(_ call: Call, completion: @escaping Call.Completion) {
        let action = CXAnswerCallAction(call: call.uuid)
        callController.requestTransaction(with: action, completion: completion)
    }
    
    func requestEndCall(_ call: Call, completion: @escaping Call.Completion) {
        let action = CXEndCallAction(call: call.uuid)
        callController.requestTransaction(with: action, completion: completion)
    }
    
    func requestSetMute(_ call: Call, muted: Bool, completion: @escaping Call.Completion) {
        let action = CXSetMutedCallAction(call: call.uuid, muted: muted)
        callController.requestTransaction(with: action, completion: completion)
    }
    
    func reportNewIncomingCall(_ call: Call, completion: @escaping Call.Completion) {
        let update = CXCallUpdate()
        update.remoteHandle = call.cxHandle
        update.localizedCallerName = call.localizedName
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false
        update.hasVideo = false
        cxProvider.reportNewIncomingCall(with: call.uuid, update: update, completion: completion)
    }
    
    func reportCall(_ call: Call, callerNameUpdatedWith name: String) {
        let update = CXCallUpdate()
        update.localizedCallerName = name
        cxProvider.reportCall(with: call.uuid, updated: update)
    }
    
    func reportOutgoingCallStartedConnecting(_ call: Call) {
        cxProvider.reportOutgoingCall(with: call.uuid, startedConnectingAt: nil)
    }
    
    func reportOutgoingCallConnected(_ call: Call) {
        cxProvider.reportOutgoingCall(with: call.uuid, connectedAt: nil)
    }
    
    func reportCall(_ call: Call, endedByReason reason: Call.EndedReason, side: Call.EndedSide) {
        let cxReason: CXCallEndedReason
        switch reason {
        case .busy:
            switch side {
            case .local:
                assertionFailure("No way this is happening")
                return
            case .remote:
                cxReason = .remoteEnded
            }
        case .declined:
            switch side {
            case .local:
                return
            case .remote:
                cxReason = .remoteEnded
            }
        case .cancelled:
            cxReason = .unanswered
        case .ended:
            switch side {
            case .local:
                return
            case .remote:
                cxReason = .remoteEnded
            }
        case .failed:
            cxReason = .failed
        }
        cxProvider.reportCall(with: call.uuid, endedAt: nil, reason: cxReason)
    }
    
}

extension CallKitAdapter: CXProviderDelegate {
    
    func providerDidReset(_ provider: CXProvider) {
        
    }
    
    func providerDidBegin(_ provider: CXProvider) {
        
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        let semaphore = DispatchSemaphore(value: 0)
        var fulfilled = false
        DispatchQueue.main.async {
            self.service.performStartCall(uuid: action.callUUID) { error in
                fulfilled = error == nil
                semaphore.signal()
            }
        }
        semaphore.wait()
        fulfilled ? action.fulfill() : action.fail()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        let semaphore = DispatchSemaphore(value: 0)
        var fulfilled = false
        DispatchQueue.main.async {
            self.service.performAnswerCall(uuid: action.callUUID) { error in
                fulfilled = error == nil
                if fulfilled {
                    // Speaker button is not working in system provided interface without this
                    // See https://stackoverflow.com/a/48806266/4014369
                    RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
                        let session = RTCAudioSession.sharedInstance()
                        session.lockForConfiguration()
                        let config: RTCAudioSessionConfiguration = .webRTC()
                        config.categoryOptions = [.allowBluetoothA2DP, .allowBluetoothHFP, .allowAirPlay]
                        try? session.setConfiguration(config)
                        session.unlockForConfiguration()
                        semaphore.signal()
                    }
                } else {
                    semaphore.signal()
                }
            }
        }
        semaphore.wait()
        fulfilled ? action.fulfill() : action.fail()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        let semaphore = DispatchSemaphore(value: 0)
        var fulfilled = false
        DispatchQueue.main.async {
            let isEndingActiveCall = self.service.activeCall?.uuid == action.callUUID
            self.service.performEndCall(uuid: action.callUUID) { error in
                fulfilled = error == nil
                if isEndingActiveCall {
                    // XXX: Alice and Bob are in a call, Carol calls Alice, Alice choose to hangup the call
                    // with Bob and pick the one with Carol, after the second call is connected, Alice will
                    // hear nothing from Carol, but Carol can hear from Alice.
                    // Don't quite know the reason, but disabling RTCAudioSession here will do the magic
                    RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
                        RTCAudioSession.sharedInstance().isAudioEnabled = false
                        semaphore.signal()
                    }
                } else {
                    semaphore.signal()
                }
            }
        }
        semaphore.wait()
        fulfilled ? action.fulfill() : action.fail()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        let error = DispatchQueue.main.sync {
            self.service.performSetMute(uuid: action.callUUID, muted: action.isMuted)
        }
        error == nil ? action.fulfill() : action.fail()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        Logger.call.info(category: "CallKitAdapter", message: "Provider reports audio session is activated")
        DispatchQueue.main.async {
            self.service.audioSessionDidActivated(audioSession)
        }
        RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
            let session = RTCAudioSession.sharedInstance()
            session.audioSessionDidActivate(audioSession)
            session.isAudioEnabled = true
        }
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        Logger.call.info(category: "CallKitAdapter", message: "Provider reports audio session is deactivated")
        RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
            let session = RTCAudioSession.sharedInstance()
            session.audioSessionDidDeactivate(audioSession)
            session.isAudioEnabled = false
        }
    }
    
}
