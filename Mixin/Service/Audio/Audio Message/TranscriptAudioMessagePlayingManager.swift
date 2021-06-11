import Foundation
import MixinServices

protocol TranscriptAudioMessagePlayingManagerDelegate: AnyObject {
    func transcriptAudioMessagePlayingManager(_ manager: TranscriptAudioMessagePlayingManager, playableMessageNextTo message: MessageItem) -> MessageItem?
}

class TranscriptAudioMessagePlayingManager: AudioMessagePlayingManager {
    
    let transcriptId: String
    
    weak var delegate: TranscriptAudioMessagePlayingManagerDelegate?
    
    init(transcriptId: String) {
        self.transcriptId = transcriptId
    }
    
    override func updateMediaStatusToRead(message: MessageItem) {
        // Do nothing. There's no read indication for audio messages inside a transcript
    }
    
    override func filePath(message: MessageItem, mediaUrl: String) -> String {
        AttachmentContainer.url(transcriptId: transcriptId, filename: mediaUrl).path
    }
    
    override func playableMessage(nextTo message: MessageItem) -> MessageItem? {
        return delegate?.transcriptAudioMessagePlayingManager(self, playableMessageNextTo: message)
    }
    
    override func preloadAudio(nextTo message: MessageItem) {
        guard let next = delegate?.transcriptAudioMessagePlayingManager(self, playableMessageNextTo: message) else {
            return
        }
        guard next.category.hasSuffix("_AUDIO"), next.mediaStatus == MediaStatus.CANCELED.rawValue || next.mediaStatus == MediaStatus.PENDING.rawValue else {
            return
        }
        let job = AttachmentDownloadJob(transcriptId: transcriptId, messageId: message.messageId)
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
}
