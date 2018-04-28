import Foundation
import UIKit
import Bugsnag

class AttachmentUploadJob: UploadOrDownloadJob {

    internal var attachResponse: AttachmentResponse?
    internal var encryptionKey: NSData? = nil
    internal var digest: NSData? = nil

    init(message: Message) {
        super.init(messageId: message.messageId)
        super.message = message
    }

    static func jobId(messageId: String) -> String {
        return "attachment-upload-\(messageId)"
    }
    
    override func getJobId() -> String {
        return AttachmentUploadJob.jobId(messageId: message.messageId)
    }

    override func execute() -> Bool {
        guard !self.message.messageId.isEmpty else {
            return false
        }

        switch MessageAPI.shared.requestAttachment() {
        case let .success(attachResponse):
            self.attachResponse = attachResponse
            guard uploadAttachment(attachResponse: attachResponse) else {
                return false
            }
        case let .failure(error):
            guard retry(error) else {
                return false
            }
        }
        return true
    }

    private func uploadAttachment(attachResponse: AttachmentResponse) -> Bool {
        guard let uploadUrl = attachResponse.uploadUrl, !uploadUrl.isEmpty, var request = try? URLRequest(url: uploadUrl, method: .put) else {
            UIApplication.trackError("AttachmentUploadJob", action: "uploadAttachment upload_url is nil", userInfo: ["uploadUrl": "\(attachResponse.uploadUrl ?? "")"])
            return false
        }
        guard let data = fileContent() else {
            UIApplication.trackError("AttachmentUploadJob", action: "uploadAttachment data is nil")
            return false
        }

        var fileData = data
        if message.category.hasPrefix("SIGNAL_") {
            fileData = Cryptography.encryptAttachmentData(data, outKey: &encryptionKey, outDigest: &digest)
            if encryptionKey == nil || digest == nil {
                UIApplication.trackError("AttachmentUploadJob", action: "uploadAttachment", userInfo: ["mediaKey": "\(encryptionKey == nil)", "mediaDigest": "\(digest == nil)"])
                return false
            }
        }
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("public-read", forHTTPHeaderField: "x-amz-acl")
        request.setValue("Connection", forHTTPHeaderField: "close")
        request.cachePolicy = .reloadIgnoringCacheData

        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        task = session.uploadTask(with: request, from: fileData, completionHandler: completionHandler)
        task?.resume()
        session.finishTasksAndInvalidate()
        return true
    }

    func fileContent() -> Data? {
        guard let mediaUrl = message.mediaUrl, !mediaUrl.isEmpty else {
            return nil
        }
        return FileManager.default.contents(atPath: MixinFile.chatPhotosUrl(mediaUrl).path)
    }

    override func taskFinished(data: Any?) {
        guard let attachResponse = self.attachResponse else {
            return
        }
        let content = getMediaDataText(attachmentId: attachResponse.attachmentId, key: encryptionKey as Data?, digest: digest as Data?)
        message.content = content
        MessageDAO.shared.updateMessageContentAndMediaStatus(content: content, mediaStatus: .DONE, messageId: message.messageId, conversationId: message.conversationId)

        SendMessageService.shared.sendMessage(message: message)
    }

    internal func getMediaDataText(attachmentId: String, key: Data?, digest: Data?) -> String {
        let transferMediaData = TransferAttachmentData(key: key, digest: digest, attachmentId: attachmentId, mineType: message.mediaMineType!, width: message.mediaWidth, height: message.mediaHeight, size:message.mediaSize!, thumbnail: message.thumbImage, name: message.name)
        return (try? jsonEncoder.encode(transferMediaData).base64EncodedString()) ?? ""
    }
}

extension AttachmentUploadJob: URLSessionTaskDelegate {

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        let change = ConversationChange(conversationId: message.conversationId,
                                        action: .updateUploadProgress(messageId: message.messageId, progress: progress))
        NotificationCenter.default.postOnMain(name: .ConversationDidChange, object: change)
    }

}
