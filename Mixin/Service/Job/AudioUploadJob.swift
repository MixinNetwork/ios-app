import Foundation

class AudioUploadJob: AttachmentUploadJob {
    
    override var fileUrl: URL? {
        guard let mediaUrl = message.mediaUrl else {
            return nil
        }
        return AttachmentContainer.url(for: .audios, filename: mediaUrl)
    }
    
    override class func jobId(messageId: String) -> String {
        return "audio-upload-\(messageId)"
    }
    
}
