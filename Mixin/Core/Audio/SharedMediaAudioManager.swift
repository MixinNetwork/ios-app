import UIKit

protocol SharedMediaAudioManagerDelegate: class {
    func sharedMediaAudioManager(_ manager: SharedMediaAudioManager, playableMessageNextTo message: MessageItem) -> MessageItem?
}

class SharedMediaAudioManager: AudioManager {
    
    weak var delegate: SharedMediaAudioManagerDelegate?
    
    override func playableMessage(nextTo message: MessageItem) -> MessageItem? {
        return delegate?.sharedMediaAudioManager(self, playableMessageNextTo: message)
    }
    
    override func preloadAudio(nextTo message: MessageItem) {
        guard let next = delegate?.sharedMediaAudioManager(self, playableMessageNextTo: message) else {
            return
        }
        guard next.category.hasSuffix("_AUDIO"), next.mediaStatus != MediaStatus.DONE.rawValue && next.mediaStatus != MediaStatus.READ.rawValue else {
            return
        }
        let job = AudioDownloadJob(messageId: next.messageId, mediaMimeType: next.mediaMimeType)
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
}
