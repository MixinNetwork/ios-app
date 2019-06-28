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
        if let playingMessageId = playingNode?.message.messageId {
            cells[playingMessageId]?.object?.isPlaying = false
        }
        cells[node.message.messageId]?.object?.isPlaying = true
        queue.async {
            let center = NotificationCenter.default
            do {
                self.playingNode = nil
                self.player?.stop()
                self.player = nil
                
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
                
                self.playingNode = node
                self.player = try AudioPlayer(path: node.path)
                self.player!.onStatusChanged = self.playerStatusChanged
                self.player!.play()
                
                if let nextNode = self.node(nextTo: node), nextNode.message.mediaStatus != MediaStatus.DONE.rawValue {
                    let job = AudioDownloadJob(messageId: nextNode.message.messageId,
                                               mediaMimeType: nextNode.message.mediaMimeType)
                    AudioJobQueue.shared.addJob(job: job)
                }
            } catch {
                DispatchQueue.main.sync {
                    self.cells[node.message.messageId]?.object?.isPlaying = false
                }
                center.removeObserver(self)
            }
        }
    }
    
    func stop(deactivateAudioSession: Bool) {
        guard let player = player else {
            return
        }
        queue.async {
            guard player.status == .playing else {
                return
            }
            if let playingNode = self.playingNode {
                DispatchQueue.main.sync {
                    self.cells[playingNode.message.messageId]?.object?.isPlaying = false
                }
                self.playingNode = nil
            }
            player.stop()
            NotificationCenter.default.removeObserver(self)
            if deactivateAudioSession {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
    }
    
    func register(cell: AudioMessageCell, forMessageId messageId: String) {
        cells[messageId] = WeakReference(object: cell)
        cell.isPlaying = messageId == playingNode?.message.messageId
    }
    
    func unregister(cell: AudioMessageCell, forMessageId messageId: String) {
        cells[messageId] = nil
    }
    
    @objc func audioSessionInterruption(_ notification: Notification) {
        stop(deactivateAudioSession: true)
    }
    
    @objc func audioSessionRouteChange(_ notification: Notification) {
        let previousOutput = (notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription)?.outputs.first
        let output = AVAudioSession.sharedInstance().currentRoute.outputs.first
        if previousOutput?.portType == .headphones, output?.portType != .headphones {
            stop(deactivateAudioSession: false)
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
                stop(deactivateAudioSession: true)
            }
        case .unknown, .oldDeviceUnavailable, .wakeFromSleep, .noSuitableRouteForCategory:
            stop(deactivateAudioSession: true)
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
                    cells[playingNode.message.messageId]?.object?.isPlaying = false
                }
                if let nextNode = self.node(nextTo: playingNode) {
                    DispatchQueue.main.sync {
                        let userInfo = [AudioManager.conversationIdUserInfoKey: nextNode.message.conversationId,
                                        AudioManager.messageIdUserInfoKey: nextNode.message.messageId]
                        NotificationCenter.default.post(name: AudioManager.willPlayNextNodeNotification, object: nil, userInfo: userInfo)
                        play(node: nextNode)
                    }
                } else {
                    DispatchQueue.main.sync {
                        cells[playingNode.message.messageId]?.object?.isPlaying = false
                    }
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
    
    private func node(nextTo node: Node) -> Node? {
        guard let nextMessage = MessageDAO.shared.getFirstAudioMessage(conversationId: node.message.conversationId, belowMessage: node.message) else {
            return nil
        }
        guard let filename = nextMessage.mediaUrl else {
            return nil
        }
        let path = MixinFile.url(ofChatDirectory: .audios, filename: filename).path
        return Node(message: nextMessage, path: path)
    }
    
}
