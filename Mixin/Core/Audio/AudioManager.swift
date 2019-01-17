import Foundation
import AVFoundation

class AudioManager {
    
    struct Node {
        let message: MessageItem
        let path: String
    }
    
    static let shared = AudioManager()
    
    let player = MXNAudioPlayer.shared()
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.audio_manager")
    
    private var cells = NSMapTable<NSString, AudioMessageCell>(keyOptions: .strongMemory, valueOptions: .weakMemory)
    private var isPlayingObservation: NSKeyValueObservation?
    private var playingNode: Node?
    
    init() {
        isPlayingObservation = player.observe(\.isPlaying) { [weak self] (player, change) in
            self?.isPlayingChanged()
        }
    }
    
    deinit {
        isPlayingObservation?.invalidate()
    }
    
    func playOrStop(node: Node) {
        let key = node.message.messageId as NSString
        if playingNode?.message.messageId == node.message.messageId {
            cells.object(forKey: key)?.isPlaying = false
            stop()
        } else {
            if let cells = cells.objectEnumerator()?.allObjects as? [AudioMessageCell] {
                cells.forEach {
                    $0.isPlaying = false
                }
            }
            cells.object(forKey: key)?.isPlaying = true
            queue.async {
                let center = NotificationCenter.default
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playback, mode: .default, options: [])
                    try session.setActive(true, options: [])
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
                    try self.player.loadFile(atPath: node.path)
                    self.player.play()
                    self.playingNode = node
                } catch {
                    self.cells.object(forKey: key)?.isPlaying = false
                    center.removeObserver(self)
                    return
                }
            }
        }
    }
    
    func stop() {
        queue.async {
            DispatchQueue.main.sync {
                if let messageId = self.playingNode?.message.messageId {
                    self.cells.object(forKey: messageId as NSString)?.isPlaying = false
                }
                self.playingNode = nil
            }
            self.player.stop()
            NotificationCenter.default.removeObserver(self)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
    
    func register(cell: AudioMessageCell, forMessageId messageId: String) {
        cells.setObject(cell, forKey: messageId as NSString)
        cell.isPlaying = messageId == playingNode?.message.messageId
    }
    
    func unregister(cell: AudioMessageCell, forMessageId messageId: String) {
        let key = messageId as NSString
        guard self.cells.object(forKey: key) == cell else {
            return
        }
        cells.removeObject(forKey: key)
    }
    
    @objc func audioSessionInterruption(_ notification: Notification) {
        stop()
    }
    
    @objc func audioSessionRouteChange(_ notification: Notification) {
        guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? AVAudioSession.RouteChangeReason else {
            return
        }
        switch reason {
        case .override, .newDeviceAvailable, .routeConfigurationChange:
            break
        case .categoryChange:
            let newCategory = AVAudioSession.sharedInstance().category
            let canContinue = newCategory == .playback || newCategory == .playAndRecord
            if !canContinue {
                stop()
            }
        case .unknown, .oldDeviceUnavailable, .wakeFromSleep, .noSuitableRouteForCategory:
            stop()
        }
    }
    
    @objc func audioSessionMediaServicesWereReset(_ notification: Notification) {
        player.dispose()
    }
    
    private func isPlayingChanged() {
        guard !player.isPlaying else {
            return
        }
        guard let messageId = playingNode?.message.messageId else {
            return
        }
        performSynchronouslyOnMainThread {
            cells.object(forKey: messageId as NSString)?.isPlaying = false
        }
        if let node = playingNode, let nextNode = self.node(nextTo: node) {
            performSynchronouslyOnMainThread {
                playOrStop(node: nextNode)
            }
        } else {
            stop()
        }
    }
    
    private func node(nextTo node: Node) -> Node? {
        guard let nextMessage = MessageDAO.shared.getMessages(conversationId: node.message.conversationId, belowMessage: node.message, count: 1).first else {
            return nil
        }
        guard nextMessage.category.hasSuffix("_AUDIO"), nextMessage.userId == node.message.userId else {
            return nil
        }
        guard let filename = nextMessage.mediaUrl else {
            return nil
        }
        let path = MixinFile.url(ofChatDirectory: .audios, filename: filename).path
        return Node(message: nextMessage, path: path)
    }
    
}
