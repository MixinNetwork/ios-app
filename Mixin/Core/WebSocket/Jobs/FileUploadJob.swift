import Foundation

class FileUploadJob: AttachmentUploadJob {

    static func fileJobId(messageId: String) -> String {
        return "file-upload-\(messageId)"
    }

    override func getJobId() -> String {
        return FileUploadJob.fileJobId(messageId: message.messageId)
    }

    override func fileContent() -> Data? {
        guard let mediaUrl = message.mediaUrl else {
            return nil
        }
        return FileManager.default.contents(atPath: MixinFile.chatFilesUrl.appendingPathComponent(mediaUrl).path)
    }

}
