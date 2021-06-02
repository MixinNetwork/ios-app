import Foundation
import MixinServices

protocol TranscriptAudioMessagePlayingManagerDelegate: AnyObject {
    func transcriptAudioMessagePlayingManager(_ manager: TranscriptAudioMessagePlayingManager, playableMessageNextTo message: MessageItem) -> MessageItem?
}

class TranscriptAudioMessagePlayingManager: AudioMessagePlayingManager {
    
    let transcriptMessage: MessageItem
    
    weak var delegate: TranscriptAudioMessagePlayingManagerDelegate?
    
    init(transcriptMessage: MessageItem) {
        self.transcriptMessage = transcriptMessage
    }
    
    override func updateMediaStatusToRead(message: MessageItem) {
        TranscriptMessageDAO.shared.updateMediaStatus(.READ,
                                                      transcriptId: transcriptMessage.messageId,
                                                      messageId: message.messageId)
    }
    
    override func filePath(message: MessageItem, mediaUrl: String) -> String {
        AttachmentContainer.url(transcriptId: transcriptMessage.messageId, filename: mediaUrl).path
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
        let message = Message.createMessage(message: message)
        let job = TranscriptAttachmentDownloadJob(transcriptMessage: transcriptMessage, message: message)
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
}
