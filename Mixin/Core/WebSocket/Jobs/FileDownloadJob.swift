import Foundation
import Bugsnag

class FileDownloadJob: AttachmentDownloadJob {

    private let fileName: String

    init(message: Message) {
        fileName = "\(message.messageId).\(FileManager.default.pathExtension(mimeType: message.mediaMineType ?? ""))"
        super.init(messageId: message.messageId)
        super.message = message
    }

    static func fileJobId(messageId: String) -> String {
        return "file-download-\(messageId)"
    }

    override func getJobId() -> String {
        return FileDownloadJob.fileJobId(messageId: message.messageId)
    }

    override func downloadFinished(data: Data) {
        let filePath = MixinFile.chatFilesUrl.appendingPathComponent(fileName)
        do {
            try? FileManager.default.removeItem(atPath: filePath.path)
            try data.write(to: filePath)
            MessageDAO.shared.updateMediaMessage(messageId: messageId, mediaUrl: fileName, status: MediaStatus.DONE, conversationId: message.conversationId)
        } catch {
            Bugsnag.notifyError(error)
        }
    }
}
