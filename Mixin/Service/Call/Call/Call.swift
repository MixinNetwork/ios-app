import Foundation
import CallKit
import MixinServices

class Call: NSObject {
    
    static let timeoutInterval: TimeInterval = 60
    
    // userInfo dictionary will contain old value for UserInfoKey.oldState
    static let stateDidChangeNotification = Notification.Name("one.mixin.messenger.Call.StateDidChange")
    
    // userInfo dictionary will contain reason for UserInfoKey.endedReason, side for UserInfoKey.side
    static let didEndNotification = Notification.Name("one.mixin.messenger.Call.DidEnd")
    
    static let mutenessDidChangeNotification = Notification.Name("one.mixin.messenger.Call.MutenessDidChange")
    static let localizedNameDidUpdateNotification = Notification.Name("one.mixin.messenger.Call.LocalizedNameDidUpdate")
    
    let uuid: UUID
    let uuidString: String
    let conversationId: String
    let rtcClient: WebRTCClient
    let queue: Queue
    let isOutgoing: Bool
    
    var internalState: State {
        didSet {
            assert(queue.isCurrent)
            Logger.call.info(category: "Call", message: "[\(uuidString)] internalState did change to: \(internalState)")
            DispatchQueue.main.sync {
                self.state = internalState
            }
        }
    }
    
    var state: State {
        didSet {
            assert(Thread.isMainThread)
            guard state != oldValue else {
                return
            }
            NotificationCenter.default.post(name: Self.stateDidChangeNotification,
                                            object: self,
                                            userInfo: [Self.UserInfoKey.oldState: oldValue])
        }
    }
    
    var isMuted = false {
        didSet {
            assert(Thread.isMainThread)
            rtcClient.isMuted = isMuted
            NotificationCenter.default.post(name: Self.mutenessDidChangeNotification, object: self)
            Logger.call.info(category: "Call", message: "[\(uuidString)] isMuted: \(isMuted)")
        }
    }
    
    var localizedName: String {
        didSet {
            assert(Thread.isMainThread)
            NotificationCenter.default.post(name: Self.localizedNameDidUpdateNotification, object: self)
        }
    }
    
    var connectedDate: Date?
    
    private weak var unansweredTimer: Timer?
    
    var cxHandle: CXHandle {
        fatalError("")
    }
    
    var localizedState: String? {
        switch state {
        case .connected:
            return formattedConnectionDuration
        default:
            return state.localizedDescription
        }
    }
    
    var briefLocalizedState: String? {
        switch state {
        case .connected:
            return formattedConnectionDuration
        case .disconnecting:
            return R.string.localizable.done()
        default:
            return R.string.localizable.waiting()
        }
    }
    
    private var formattedConnectionDuration: String? {
        guard let date = connectedDate else {
            return nil
        }
        let duration = abs(date.timeIntervalSinceNow)
        return CallDurationFormatter.string(from: duration)
    }
    
    init(uuid: UUID, conversationId: String, isOutgoing: Bool, state: State, localizedName: String) {
        let uuidString = uuid.uuidString.lowercased()
        self.uuid = uuid
        self.uuidString = uuidString
        self.conversationId = conversationId
        self.rtcClient = WebRTCClient()
        self.queue = Queue(label: "one.mixin.messenger.Call-" + uuidString)
        self.isOutgoing = isOutgoing
        self.internalState = state
        self.state = state
        self.localizedName = localizedName
        super.init()
    }
    
    func end(reason: EndedReason, by side: EndedSide, completion: (() -> Void)? = nil) {
        fatalError("Must override")
    }
    
    // MARK: - Unanswered Timer
    func scheduleUnansweredTimer() {
        Queue.main.autoSync {
            guard self.unansweredTimer == nil else {
                Logger.call.warn(category: "Call", message: "[\(self.uuidString)] Unanswered timer gets scheduled multiple times")
                return
            }
            self.unansweredTimer = Timer.scheduledTimer(timeInterval: Self.timeoutInterval,
                                                        target: self,
                                                        selector: #selector(answeringTimedOut),
                                                        userInfo: nil,
                                                        repeats: false)
        }
    }
    
    func invalidateUnansweredTimer() {
        Queue.main.autoSync {
            self.unansweredTimer?.invalidate()
            self.unansweredTimer = nil
        }
    }
    
    @objc private func answeringTimedOut() {
        assert(Thread.isMainThread)
        Logger.call.info(category: "Call", message: "[\(uuidString)] Answering timed out")
        invalidateUnansweredTimer()
        end(reason: .cancelled, by: .local)
    }
    
}

// MARK: - Definitions
extension Call {
    
    enum State {
        
        case incoming
        case outgoing
        case connecting
        case connected
        case restarting
        case disconnecting
        
        var localizedDescription: String {
            switch self {
            case .incoming:
                return R.string.localizable.incoming_voice_call()
            case .outgoing:
                return R.string.localizable.calling()
            case .connecting:
                return R.string.localizable.connecting()
            case .connected:
                return R.string.localizable.connected()
            case .restarting:
                return R.string.localizable.connection_unstable()
            case .disconnecting:
                return R.string.localizable.disconnecting()
            }
        }
        
    }
    
    enum EndedSide {
        case local
        case remote
    }
    
    enum EndedReason {
        
        case busy
        case declined
        case cancelled
        case ended
        case failed
        
        init(error: Error) {
            if let error = error as? CXErrorCodeIncomingCallError, [.filteredByBlockList, .filteredByDoNotDisturb].contains(error.code) {
                self = .declined
            } else if let error = error as? CallError {
                switch error {
                case .busy:
                    self = .busy
                case .microphonePermissionDenied:
                    self = .declined
                default:
                    self = .failed
                }
            } else {
                self = .failed
            }
        }
        
    }
    
    enum UserInfoKey {
        static let oldState = "olst"
        static let endedReason = "enre"
        static let endedSide = "ensi"
    }
    
    typealias Completion = (Error?) -> Void
    
}
