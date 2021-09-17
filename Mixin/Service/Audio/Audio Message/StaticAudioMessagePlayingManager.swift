import Foundation
import MixinServices

protocol StaticAudioMessagePlayingManagerDelegate: AnyObject {
    func staticAudioMessagePlayingManager(_ manager: StaticAudioMessagePlayingManager, playableMessageNextTo message: MessageItem) -> MessageItem?
}

class StaticAudioMessagePlayingManager: AudioMessagePlayingManager {
    
    weak var delegate: StaticAudioMessagePlayingManagerDelegate?
    
    override func playableMessage(nextTo message: MessageItem) -> MessageItem? {
        return delegate?.staticAudioMessagePlayingManager(self, playableMessageNextTo: message)
    }
    
    override func preloadAudio(nextTo message: MessageItem) {
        guard let next = delegate?.staticAudioMessagePlayingManager(self, playableMessageNextTo: message) else {
            return
        }
        guard next.category.hasSuffix("_AUDIO"), next.mediaStatus == MediaStatus.CANCELED.rawValue || next.mediaStatus == MediaStatus.PENDING.rawValue else {
            return
        }
        let job = AttachmentDownloadJob(messageId: next.messageId)
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
}
