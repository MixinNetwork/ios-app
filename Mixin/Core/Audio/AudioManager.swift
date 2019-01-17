import Foundation
import AVFoundation

class AudioManager {
    
    struct Node {
        let messageId: String
        let path: String
    }
    
    static let shared = AudioManager()
    
    let player = MXNAudioPlayer.shared()
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.audio_manager")
    
    private var cells = NSMapTable<NSString, AudioMessageCell>(keyOptions: .strongMemory, valueOptions: .weakMemory)
    private var isPlayingObservation: NSKeyValueObservation?
    private var playingMessageId: String?
    
    init() {
        isPlayingObservation = player.observe(\.isPlaying) { [weak self] (player, change) in
            self?.isPlayingChanged()
        }
    }
    
    deinit {
        isPlayingObservation?.invalidate()
    }
    
    func playOrStop(node: Node) {
        let key = node.messageId as NSString
        if playingMessageId == node.messageId {
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
                let session = AVAudioSession.sharedInstance()
                do {
                    try session.setCategory(.playback, mode: .default, options: [])
                    try session.setActive(true, options: [])
                    try self.player.loadFile(atPath: node.path)
                    self.player.play()
                    self.playingMessageId = node.messageId
                } catch {
                    self.cells.object(forKey: key)?.isPlaying = false
                    return
                }
            }
        }
    }
    
    func stop() {
        queue.async {
            self.player.stop()
            self.playingMessageId = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
    
    func register(cell: AudioMessageCell, forMessageId messageId: String) {
        cells.setObject(cell, forKey: messageId as NSString)
        cell.isPlaying = messageId == playingMessageId
    }
    
    func unregister(cell: AudioMessageCell, forMessageId messageId: String) {
        let key = messageId as NSString
        guard self.cells.object(forKey: key) == cell else {
            return
        }
        cells.removeObject(forKey: key)
    }
    
    private func isPlayingChanged() {
        guard !player.isPlaying else {
            return
        }
        guard let messageId = playingMessageId else {
            return
        }
        performSynchronouslyOnMainThread {
            playingMessageId = nil
            cells.object(forKey: messageId as NSString)?.isPlaying = false
        }
    }
    
}
