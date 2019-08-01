import Foundation
import AVFoundation

class AudioManager {
    
    struct Node {
        let message: MessageItem
        let path: String
    }
    
    struct WeakReference<T: AnyObject> {
        weak var object: T?
    }
    
    static let shared = AudioManager()
    static let willPlayNextNodeNotification = Notification.Name("one.mixin.messenger.audio_manager.will_play_next")
    static let conversationIdUserInfoKey = "conversation_id"
    static let messageIdUserInfoKey = "message_id"
    
    private(set) var player: AudioPlayer?
    private(set) var playingNode: Node?
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.audio_manager")
    private let queueSpecificKey = DispatchSpecificKey<Void>()
    
    private var cells = [String: WeakReference<AudioMessageCell>]()
    
    init() {
        queue.setSpecific(key: queueSpecificKey, value: ())
    }
    
    func play(node: Node) {
        
        func handle(error: Error) {
            DispatchQueue.main.sync {
                self.cells[node.message.messageId]?.object?.style = .stopped
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
        
        cells[node.message.messageId]?.object?.style = .playing
        
        if node.message.messageId == playingNode?.message.messageId, let player = player {
            queue.async {
                resetAudioSession()
                player.play()
            }
            return
        }
        
        if let playingMessageId = playingNode?.message.messageId {
            cells[playingMessageId]?.object?.style = .stopped
        }
        
        queue.async {
            do {
                if node.message.mediaStatus != MediaStatus.READ.rawValue && node.message.userId != AccountAPI.shared.accountUserId {
                    MessageDAO.shared.updateMediaStatus(messageId: node.message.messageId,
                                                        status: .READ,
                                                        conversationId: node.message.conversationId)
                }
                
                self.playingNode = nil
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
                
                self.playingNode = node
                self.player = try AudioPlayer(path: node.path)
                self.player!.onStatusChanged = self.playerStatusChanged
                self.player!.play()
                
                self.preloadAudio(nextTo: node.message)
            } catch {
                handle(error: error)
            }
        }
    }
    
    func pause() {
        guard let playingNode = playingNode else {
            return
        }
        cells[playingNode.message.messageId]?.object?.style = .paused
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
            if let playingNode = self.playingNode {
                DispatchQueue.main.sync {
                    self.cells[playingNode.message.messageId]?.object?.style = .stopped
                }
                self.playingNode = nil
            }
            player.stop()
            NotificationCenter.default.removeObserver(self)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
    
    func register(cell: AudioMessageCell, forMessageId messageId: String) {
        cells[messageId] = WeakReference(object: cell)
        if messageId == playingNode?.message.messageId, let player = player {
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
    
    func unregister(cell: AudioMessageCell, forMessageId messageId: String) {
        cells[messageId] = nil
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
        let previousOutput = (notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription)?.outputs.first
        let output = AVAudioSession.sharedInstance().currentRoute.outputs.first
        if previousOutput?.portType == .headphones, output?.portType != .headphones {
            pause()
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
    
    private func playerStatusChanged(player: AudioPlayer) {
        
        func handleStatusChange() {
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = player.status == .playing
            }
            if player.status == .didReachEnd, let playingNode = playingNode {
                DispatchQueue.main.sync {
                    cells[playingNode.message.messageId]?.object?.style = .stopped
                }
                if let nextNode = self.playableNode(nextTo: playingNode) {
                    DispatchQueue.main.sync {
                        let userInfo = [AudioManager.conversationIdUserInfoKey: nextNode.message.conversationId,
                                        AudioManager.messageIdUserInfoKey: nextNode.message.messageId]
                        NotificationCenter.default.post(name: AudioManager.willPlayNextNodeNotification, object: nil, userInfo: userInfo)
                        play(node: nextNode)
                    }
                } else {
                    self.playingNode = nil
                    NotificationCenter.default.removeObserver(self)
                    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                }
            }
        }
        
        if DispatchQueue.getSpecific(key: queueSpecificKey) == nil {
            queue.async(execute: handleStatusChange)
        } else {
            handleStatusChange()
        }
    }
    
    private func playableNode(nextTo node: Node) -> Node? {
        guard let nextMessage = MessageDAO.shared.getMessages(conversationId: node.message.conversationId, belowMessage: node.message, count: 1).first else {
            return nil
        }
        guard nextMessage.category.hasSuffix("_AUDIO"), let filename = nextMessage.mediaUrl else {
            return nil
        }
        guard nextMessage.mediaStatus == MediaStatus.DONE.rawValue || nextMessage.mediaStatus == MediaStatus.READ.rawValue else {
            return nil
        }
        let path = MixinFile.url(ofChatDirectory: .audios, filename: filename).path
        return Node(message: nextMessage, path: path)
    }
    
    private func preloadAudio(nextTo message: MessageItem) {
        guard let next = MessageDAO.shared.getMessages(conversationId: message.conversationId, belowMessage: message, count: 1).first else {
            return
        }
        guard next.category.hasSuffix("_AUDIO"), next.mediaStatus != MediaStatus.DONE.rawValue && next.mediaStatus != MediaStatus.READ.rawValue else {
            return
        }
        let job = AudioDownloadJob(messageId: next.messageId, mediaMimeType: next.mediaMimeType)
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
}
