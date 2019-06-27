import Foundation
import AVFoundation

class AudioManager {
    
    struct Node {
        let message: MessageItem
        let path: String
    }
    
    static let shared = AudioManager()
    static let willPlayNextNodeNotification = Notification.Name("one.mixin.messenger.audio_manager.will_play_next")
    
    let player = MXNAudioPlayer.shared()
    
    private(set) var playingNode: Node?
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.audio_manager")
    
    private var cells = NSMapTable<NSString, AudioMessageCell>(keyOptions: .strongMemory, valueOptions: .weakMemory)
    private var isPlayingObservation: NSKeyValueObservation?
    
    init() {
        isPlayingObservation = player.observe(\.isPlaying) { [weak self] (player, change) in
            self?.isPlayingChanged()
        }
    }
    
    deinit {
        isPlayingObservation?.invalidate()
    }
    
    func play(node: Node) {
        let key = node.message.messageId as NSString
        (cells.objectEnumerator()?.allObjects as? [AudioMessageCell])?.forEach {
            $0.isPlaying = false
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
                
                self.playingNode = nil
                try self.player.loadFile(atPath: node.path)
                self.player.play()
                self.playingNode = node
                if let nextNode = self.node(nextTo: node), nextNode.message.mediaStatus != MediaStatus.DONE.rawValue {
                    let job = AudioDownloadJob(messageId: nextNode.message.messageId,
                                               mediaMimeType: nextNode.message.mediaMimeType)
                    AudioJobQueue.shared.addJob(job: job)
                }
            } catch {
                self.cells.object(forKey: key)?.isPlaying = false
                center.removeObserver(self)
            }
        }
    }
    
    func stop(deactivateAudioSession: Bool) {
        queue.async {
            guard self.player.isPlaying else {
                return
            }
            self.updateCellsAndPlayingNodeForStopping()
            self.player.stop()
            NotificationCenter.default.removeObserver(self)
            if deactivateAudioSession {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
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
        player.dispose()
    }
    
    private func updateCellsAndPlayingNodeForStopping() {
        performSynchronouslyOnMainThread {
            if let messageId = self.playingNode?.message.messageId {
                self.cells.object(forKey: messageId as NSString)?.isPlaying = false
            }
            self.playingNode = nil
        }
    }
    
    private func isPlayingChanged() {
        let isPlaying = player.isPlaying
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = isPlaying
        }
        guard !isPlaying else {
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
                NotificationCenter.default.post(name: AudioManager.willPlayNextNodeNotification, object: nextNode.message.messageId)
                play(node: nextNode)
            }
        } else {
            updateCellsAndPlayingNodeForStopping()
            NotificationCenter.default.removeObserver(self)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
