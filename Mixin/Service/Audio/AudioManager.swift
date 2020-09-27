import Foundation
import AVFoundation
import MixinServices

class AudioManager: NSObject {
    
    struct WeakCellBox {
        weak var cell: AudioCell?
    }
    
    static let shared = AudioManager()
    static let willPlayNextNotification = Notification.Name("one.mixin.messenger.AudioManager.willPlayNext")
    static let willPlayPreviousNotification = Notification.Name("one.mixin.messenger.AudioManager.willPlayPrevious")
    static let conversationIdUserInfoKey = "conversation_id"
    static let messageIdUserInfoKey = "message_id"
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.AudioManager")
    
    // These 2 vars below should be access from main queue
    private(set) var player: AudioPlayer?
    private(set) var playingMessage: MessageItem?
    
    private var cells = [String: WeakCellBox]()
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(willRecallMessage(_:)), name: SendMessageService.willRecallMessageNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func play(message: MessageItem) {
        guard let mediaUrl = message.mediaUrl else {
            return
        }
        
        if let controller = UIApplication.homeContainerViewController?.pipController {
            controller.pauseAction(self)
            controller.controlView.set(playControlsHidden: false, otherControlsHidden: false, animated: true)
        }
        
        let shouldUpdateMediaStatus = message.mediaStatus != MediaStatus.READ.rawValue && message.userId != myUserId
        cells[message.messageId]?.cell?.style = .playing
        
        func handle(error: Error) {
            performSynchronouslyOnMainThread {
                self.cells[message.messageId]?.cell?.style = .stopped
                NotificationCenter.default.removeObserver(self)
            }
        }
        
        func resetAudioSession() {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [])
                try session.setActive(true, options: [])
            } catch {
                handle(error: error)
            }
        }
        
        if message.messageId == playingMessage?.messageId, let player = player {
            queue.async {
                resetAudioSession()
                DispatchQueue.main.sync(execute: player.play)
            }
            return
        }
        
        if let playingMessageId = playingMessage?.messageId {
            cells[playingMessageId]?.cell?.style = .stopped
            self.playingMessage = nil
        }
        if let player = self.player {
            player.stop()
            self.player = nil
        }
        self.playingMessage = message
        
        queue.async {
            if shouldUpdateMediaStatus {
                MessageDAO.shared.updateMediaStatus(messageId: message.messageId,
                                                    status: .READ,
                                                    conversationId: message.conversationId)
            }
            
            resetAudioSession()
            
            let center = NotificationCenter.default
            center.addObserver(self,
                               selector: #selector(AudioManager.audioSessionInterruption(_:)),
                               name: AVAudioSession.interruptionNotification,
                               object: nil)
            center.addObserver(self,
                               selector: #selector(AudioManager.audioSessionRouteChange(_:)),
                               name: AVAudioSession.routeChangeNotification,
                               object: nil)
            center.addObserver(self,
                               selector: #selector(AudioManager.audioSessionMediaServicesWereReset(_:)),
                               name: AVAudioSession.mediaServicesWereResetNotification,
                               object: nil)
            center.addObserver(self,
                               selector: #selector(AudioManager.pause),
                               name: CallService.willStartCallNotification,
                               object: nil)
            let path = AttachmentContainer.url(for: .audios, filename: mediaUrl).path
            
            DispatchQueue.main.sync {
                guard self.playingMessage?.messageId == message.messageId else {
                    return
                }
                do {
                    let player = try AudioPlayer(path: path)
                    player.onStatusChanged = { [weak self] player in
                        self?.handleStatusChange(player: player)
                    }
                    player.play()
                    self.player = player
                } catch {
                    handle(error: error)
                }
            }
            
            self.preloadAudio(nextTo: message)
        }
    }
    
    @objc func pause() {
        guard let playingMessage = playingMessage else {
            return
        }
        cells[playingMessage.messageId]?.cell?.style = .paused
        player?.pause()
    }
    
    func stop() {
        guard let player = player else {
            return
        }
        guard player.status == .playing || player.status == .paused else {
            return
        }
        if let playingMessage = self.playingMessage {
            self.cells[playingMessage.messageId]?.cell?.style = .stopped
            self.playingMessage = nil
        }
        player.stop()
        NotificationCenter.default.removeObserver(self)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    func register(cell: AudioCell, forMessageId messageId: String) {
        cells[messageId] = WeakCellBox(cell: cell)
        if messageId == playingMessage?.messageId, let player = player {
            switch player.status {
            case .playing:
                cell.style = .playing
            case .paused:
                cell.style = .paused
            case .readyToPlay, .didReachEnd:
                cell.style = .stopped
            }
        } else {
            cell.style = .stopped
        }
    }
    
    func unregister(cell: AudioCell, forMessageId messageId: String) {
        cells[messageId] = nil
    }
    
    func playableMessage(nextTo message: MessageItem) -> MessageItem? {
        guard let nextMessage = MessageDAO.shared.getMessages(conversationId: message.conversationId, belowMessage: message, count: 1).first else {
            return nil
        }
        guard nextMessage.category.hasSuffix("_AUDIO"), nextMessage.mediaUrl != nil else {
            return nil
        }
        guard nextMessage.mediaStatus == MediaStatus.DONE.rawValue || nextMessage.mediaStatus == MediaStatus.READ.rawValue else {
            return nil
        }
        return nextMessage
    }
    
    func preloadAudio(nextTo message: MessageItem) {
        guard let next = MessageDAO.shared.getMessages(conversationId: message.conversationId, belowMessage: message, count: 1).first else {
            return
        }
        guard next.category.hasSuffix("_AUDIO"), next.mediaStatus != MediaStatus.DONE.rawValue && next.mediaStatus != MediaStatus.READ.rawValue else {
            return
        }
        let job = AudioDownloadJob(messageId: next.messageId)
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
    @objc func willRecallMessage(_ notification: Notification) {
        guard let messageId = notification.userInfo?[MixinService.UserInfoKey.messageId] as? String else {
            return
        }
        guard playingMessage?.messageId == messageId else {
            return
        }
        stop()
    }
    
    @objc func audioSessionInterruption(_ notification: Notification) {
        guard let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt, let type = AVAudioSession.InterruptionType(rawValue: value) else {
            return
        }
        if type == .began {
            DispatchQueue.main.async(execute: pause)
        }
    }
    
    @objc func audioSessionRouteChange(_ notification: Notification) {
        func pause() {
            DispatchQueue.main.async(execute: self.pause)
        }
        let previousOutput = (notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription)?.outputs.first
        let output = AVAudioSession.sharedInstance().currentRoute.outputs.first
        if previousOutput?.portType == .headphones, output?.portType != .headphones {
            pause()
            return
        }
        guard let value = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? AVAudioSession.RouteChangeReason.RawValue, let reason = AVAudioSession.RouteChangeReason(rawValue: value) else {
            return
        }
        switch reason {
        case .override, .newDeviceAvailable, .routeConfigurationChange:
            break
        case .categoryChange:
            let newCategory = AVAudioSession.sharedInstance().category
            let canContinue = newCategory == .playback || newCategory == .playAndRecord
            if !canContinue {
                pause()
            }
        case .unknown, .oldDeviceUnavailable, .wakeFromSleep, .noSuitableRouteForCategory:
            pause()
        @unknown default:
            pause()
        }
    }
    
    @objc func audioSessionMediaServicesWereReset(_ notification: Notification) {
        DispatchQueue.main.async {
            self.player?.dispose()
            self.player = nil
        }
    }
    
    func handleStatusChange(player: AudioPlayer) {
        UIApplication.shared.isIdleTimerDisabled = player.status == .playing
        if player.status == .didReachEnd, let playingMessage = playingMessage {
            cells[playingMessage.messageId]?.cell?.style = .stopped
            DispatchQueue.global().async {
                if let next = self.playableMessage(nextTo: playingMessage) {
                    DispatchQueue.main.async {
                        let userInfo = [AudioManager.conversationIdUserInfoKey: next.conversationId,
                                        AudioManager.messageIdUserInfoKey: next.messageId]
                        NotificationCenter.default.post(name: AudioManager.willPlayNextNotification, object: self, userInfo: userInfo)
                        self.play(message: next)
                    }
                } else {
                    DispatchQueue.main.sync {
                        self.playingMessage = nil
                        NotificationCenter.default.removeObserver(self)
                    }
                    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                }
            }
        }
    }
    
}
