import Foundation
import MixinServices

protocol StaticAudioMessagePlayingManagerDelegate: AnyObject {
    func staticAudioMessagePlayingManager(_ manager: StaticAudioMessagePlayingManager, playableMessageNextTo message: MessageItem) -> MessageItem?
}

class StaticAudioMessagePlayingManager: AudioMessagePlayingManager {

    let staticMessageId: String
    
    weak var delegate: StaticAudioMessagePlayingManagerDelegate?
    
    init(staticMessageId: String) {
        self.staticMessageId = staticMessageId
    }
    
    override func updateMediaStatusToRead(message: MessageItem) {
        // Do nothing. There's no read indication for audio messages inside a transcript
    }
    
    override func filePath(message: MessageItem, mediaUrl: String) -> String {
        //TODO: ‼️ fix transcriptId
        AttachmentContainer.url(transcriptId: staticMessageId, filename: mediaUrl).path
    }
    
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
        //TODO: ‼️ fix transcriptId
        let job = AttachmentDownloadJob(transcriptId: staticMessageId, messageId: message.messageId)
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
}
