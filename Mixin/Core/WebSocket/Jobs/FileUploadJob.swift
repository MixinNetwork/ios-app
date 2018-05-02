import Foundation

class FileUploadJob: AttachmentUploadJob {

    override var fileUrl: URL? {
        guard let mediaUrl = message.mediaUrl else {
            return nil
        }
        return MixinFile.chatFilesUrl.appendingPathComponent(mediaUrl)
    }
    
    static func fileJobId(messageId: String) -> String {
        return "file-upload-\(messageId)"
    }

    override func getJobId() -> String {
        return FileUploadJob.fileJobId(messageId: message.messageId)
    }

}
