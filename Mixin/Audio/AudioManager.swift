import Foundation
import AVFoundation

class AudioManager: NSObject {
    
    struct WeakCellBox {
        weak var cell: AudioCell?
    }
    
    static let shared = AudioManager()
    static let willPlayNextNotification = Notification.Name("one.mixin.messenger.audio_manager.will_play_next")
    static let willPlayPreviousNotification = Notification.Name("one.mixin.messenger.audio_manager.will_play_previous")
    static let conversationIdUserInfoKey = "conversation_id"
    static let messageIdUserInfoKey = "message_id"
    
    private(set) var player: AudioPlayer?
    private(set) var playingMessage: MessageItem?
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.audio_manager")
    private let queueSpecificKey = DispatchSpecificKey<Void>()
    
    private var cells = [String: WeakCellBox]()
    
    override init() {
        super.init()
        queue.setSpecific(key: queueSpecificKey, value: ())
    }
    
    func play(message: MessageItem) {
        guard let mediaUrl = message.mediaUrl else {
            return
        }
        
        func handle(error: Error) {
            DispatchQueue.main.sync {
                self.cells[message.messageId]?.cell?.style = .stopped
            }
            NotificationCenter.default.removeObserver(self)
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
        
        if let controller = UIApplication.homeContainerViewController?.pipController {
            controller.pauseAction(self)
            controller.controlView.set(playControlsHidden: false, otherControlsHidden: false, animated: true)
        }
        
        let shouldUpdateMediaStatus = message.mediaStatus != MediaStatus.READ.rawValue && message.userId != AccountAPI.shared.accountUserId
        cells[message.messageId]?.cell?.style = .playing
        
        if message.messageId == playingMessage?.messageId, let player = player {
            queue.async {
                resetAudioSession()
                player.play()
            }
            return
        }
        
        if let playingMessageId = playingMessage?.messageId {
            cells[playingMessageId]?.cell?.style = .stopped
        }
        
        queue.async {
            do {
                if shouldUpdateMediaStatus {
                    MessageDAO.shared.updateMediaStatus(messageId: message.messageId,
                                                        status: .READ,
                                                        conversationId: message.conversationId)
                }
                
                self.playingMessage = nil
                self.player?.stop()
                self.player = nil
                
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
                
                let path = MixinFile.url(ofChatDirectory: .audios, filename: mediaUrl).path
                
                self.playingMessage = message
                self.player = try AudioPlayer(path: path)
                self.player!.onStatusChanged = { [weak self] player in
                    guard let weakSelf = self else {
                        return
                    }
                    if DispatchQueue.getSpecific(key: weakSelf.queueSpecificKey) == nil {
                        weakSelf.queue.async {
                            weakSelf.handleStatusChange(player: player)
                        }
                    } else {
                        weakSelf.handleStatusChange(player: player)
                    }
                }
                self.player!.play()
                
                self.preloadAudio(nextTo: message)
            } catch {
                handle(error: error)
            }
        }
    }
    
    func pause() {
        guard let playingMessage = playingMessage else {
            return
        }
        cells[playingMessage.messageId]?.cell?.style = .paused
        queue.async {
            self.player?.pause()
        }
    }
    
    func stop() {
        guard let player = player else {
            return
        }
        queue.async {
            guard player.status == .playing || player.status == .paused else {
                return
            }
            if let playingMessage = self.playingMessage {
                DispatchQueue.main.sync {
                    self.cells[playingMessage.messageId]?.cell?.style = .stopped
                }
                self.playingMessage = nil
            }
            player.stop()
            NotificationCenter.default.removeObserver(self)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
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
        let job = AudioDownloadJob(messageId: next.messageId, mediaMimeType: next.mediaMimeType)
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
    @objc func audioSessionInterruption(_ notification: Notification) {
        guard let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt, let type = AVAudioSession.InterruptionType(rawValue: value) else {
            return
        }
        if type == .began {
            pause()
        }
    }
    
    @objc func audioSessionRouteChange(_ notification: Notification) {
        let pause = {
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
        player?.dispose()
        player = nil
    }
    
    func handleStatusChange(player: AudioPlayer) {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = player.status == .playing
        }
        if player.status == .didReachEnd, let playingMessage = playingMessage {
            DispatchQueue.main.sync {
                cells[playingMessage.messageId]?.cell?.style = .stopped
            }
            if let next = self.playableMessage(nextTo: playingMessage) {
                DispatchQueue.main.sync {
                    let userInfo = [AudioManager.conversationIdUserInfoKey: next.conversationId,
                                    AudioManager.messageIdUserInfoKey: next.messageId]
                    NotificationCenter.default.post(name: AudioManager.willPlayNextNotification, object: self, userInfo: userInfo)
                    play(message: next)
                }
            } else {
                self.playingMessage = nil
                NotificationCenter.default.removeObserver(self)
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
    }
    
}
