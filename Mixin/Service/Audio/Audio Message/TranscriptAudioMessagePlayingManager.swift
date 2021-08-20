import Foundation
import MixinServices

class TranscriptAudioMessagePlayingManager: StaticAudioMessagePlayingManager {
    
    let transcriptId: String
    
    init(transcriptId: String) {
        self.transcriptId = transcriptId
    }
    
    override func filePath(message: MessageItem, mediaUrl: String) -> String {
        AttachmentContainer.url(transcriptId: transcriptId, filename: mediaUrl).path
    }
    
    override func preloadAudio(nextTo message: MessageItem) {
        guard let next = delegate?.staticAudioMessagePlayingManager(self, playableMessageNextTo: message) else {
            return
        }
        guard next.category.hasSuffix("_AUDIO"), next.mediaStatus == MediaStatus.CANCELED.rawValue || next.mediaStatus == MediaStatus.PENDING.rawValue else {
            return
        }
        let job = AttachmentDownloadJob(transcriptId: transcriptId, messageId: message.messageId)
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
}
