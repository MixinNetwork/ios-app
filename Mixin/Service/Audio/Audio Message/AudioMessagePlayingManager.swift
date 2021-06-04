import Foundation
import AVFoundation
import MixinServices

class AudioMessagePlayingManager: NSObject, AudioSessionClient {
    
    struct WeakCellBox {
        weak var cell: AudioCell?
    }
    
    static let shared = AudioMessagePlayingManager()
    static let willPlayNextNotification = Notification.Name("one.mixin.messenger.AudioMessagePlayingManager.willPlayNext")
    static let willPlayPreviousNotification = Notification.Name("one.mixin.messenger.AudioMessagePlayingManager.willPlayPrevious")
    static let conversationIdUserInfoKey = "conversation_id"
    static let messageIdUserInfoKey = "message_id"
    
    var pausePlayingWhenAppEntersBackground: Bool {
        true
    }
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.AudioMessagePlayingManager")
    
    // These 2 vars below should be access from main queue
    private(set) var player: OggOpusPlayer?
    private(set) var playingMessage: MessageItem?
    
    private var cells = [String: WeakCellBox]()
    private var displayAwakeningToken: DisplayAwakener.Token?
    
    override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(willRecallMessage(_:)),
                           name: SendMessageService.willRecallMessageNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(appDidEnterBackgroundNotification(_:)),
                           name: UIApplication.didEnterBackgroundNotification,
                           object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func play(message: MessageItem) {
        guard let mediaUrl = message.mediaUrl else {
            return
        }
        
        let shouldUpdateMediaStatus = message.mediaStatus != MediaStatus.READ.rawValue && message.userId != myUserId
        cells[message.messageId]?.cell?.style = .playing
        
        func handle(error: Error) {
            Queue.main.autoSync {
                self.cells[message.messageId]?.cell?.style = .stopped
                NotificationCenter.default.removeObserver(self)
            }
        }
        
        func activateAudioSession() {
            do {
                try AudioSession.shared.activate(client: self) { (session) in
                    try session.setCategory(.playback, mode: .default, options: [])
                }
            } catch {
                handle(error: error)
            }
        }
        
        if message.messageId == playingMessage?.messageId, let player = player {
            queue.async {
                activateAudioSession()
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
                self.updateMediaStatusToRead(message: message)
            }
            
            activateAudioSession()
            let path = self.filePath(message: message, mediaUrl: mediaUrl)
            DispatchQueue.main.sync {
                guard self.playingMessage?.messageId == message.messageId else {
                    return
                }
                do {
                    let player = try OggOpusPlayer(path: path)
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
    
    func pause() {
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
        AudioSession.shared.deactivateAsynchronously(client: self, notifyOthersOnDeactivation: true)
    }
    
    func register(cell: AudioCell, forMessageId messageId: String) {
        cells[messageId] = WeakCellBox(cell: cell)
        if messageId == playingMessage?.messageId, let player = player {
            switch player.status {
            case .playing:
                cell.style = .playing
            case .paused:
                cell.style = .paused
            case .stopped:
                cell.style = .stopped
            }
        } else {
            cell.style = .stopped
        }
    }
    
    func unregister(cell: AudioCell, forMessageId messageId: String) {
        cells[messageId] = nil
    }
    
    func updateMediaStatusToRead(message: MessageItem) {
        MessageDAO.shared.updateMediaStatus(messageId: message.messageId,
                                            status: .READ,
                                            conversationId: message.conversationId)
    }
    
    func filePath(message: MessageItem, mediaUrl: String) -> String {
        AttachmentContainer.url(for: .audios, filename: mediaUrl).path
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
        let job = AttachmentDownloadJob(messageId: next.messageId)
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
    @objc func appDidEnterBackgroundNotification(_ notification: Notification) {
        if pausePlayingWhenAppEntersBackground {
            pause()
        }
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
    
    func handleStatusChange(player: OggOpusPlayer) {
        if let token = displayAwakeningToken {
            DisplayAwakener.shared.release(token: token)
            displayAwakeningToken = nil
        }
        if player.status == .playing {
            displayAwakeningToken = DisplayAwakener.shared.retain()
        }
        if player.status == .stopped, let playingMessage = playingMessage {
            cells[playingMessage.messageId]?.cell?.style = .stopped
            DispatchQueue.global().async {
                if let next = self.playableMessage(nextTo: playingMessage) {
                    DispatchQueue.main.async {
                        let userInfo = [AudioMessagePlayingManager.conversationIdUserInfoKey: next.conversationId,
                                        AudioMessagePlayingManager.messageIdUserInfoKey: next.messageId]
                        NotificationCenter.default.post(name: AudioMessagePlayingManager.willPlayNextNotification, object: self, userInfo: userInfo)
                        self.play(message: next)
                    }
                } else {
                    DispatchQueue.main.sync {
                        self.playingMessage = nil
                    }
                    try? AudioSession.shared.deactivate(client: self, notifyOthersOnDeactivation: true)
                }
            }
        }
    }
    
    // MARK: - AudioSessionClient
    var priority: AudioSessionClientPriority {
        .playback
    }
    
    func audioSessionDidBeganInterruption(_ audioSession: AudioSession) {
        pause()
    }
    
    func audioSession(_ audioSession: AudioSession, didChangeRouteFrom previousRoute: AVAudioSessionRouteDescription, reason: AVAudioSession.RouteChangeReason) {
        let previousOutput = previousRoute.outputs.first
        let output = audioSession.avAudioSession.currentRoute.outputs.first
        if previousOutput?.portType == .headphones, output?.portType != .headphones {
            DispatchQueue.main.async(execute: pause)
            return
        }
        switch reason {
        case .override, .newDeviceAvailable, .routeConfigurationChange:
            break
        case .categoryChange:
            let newCategory = audioSession.avAudioSession.category
            let canContinue = newCategory == .playback || newCategory == .playAndRecord
            if !canContinue {
                DispatchQueue.main.async(execute: pause)
            }
        case .unknown, .oldDeviceUnavailable, .wakeFromSleep, .noSuitableRouteForCategory:
            DispatchQueue.main.async(execute: pause)
        @unknown default:
            DispatchQueue.main.async(execute: pause)
        }
    }
    
    func audioSessionMediaServicesWereReset(_ audioSession: AudioSession) {
        DispatchQueue.main.async {
            self.player?.dispose()
            self.player = nil
        }
    }
    
}
