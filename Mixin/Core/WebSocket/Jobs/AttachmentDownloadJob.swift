import Foundation
import UIKit
import Bugsnag

class AttachmentDownloadJob: UploadOrDownloadJob {

    private let imageName: String

    override init(messageId: String) {
        self.imageName = "\(messageId).jpg"
        super.init(messageId: messageId)
    }

    static func jobId(messageId: String) -> String {
        return "attachment-download-\(messageId)"
    }
    
    override func getJobId() -> String {
        return AttachmentDownloadJob.jobId(messageId: messageId)
    }

    override func execute() -> Bool {
        guard !self.messageId.isEmpty else {
            return false
        }
        guard let message = MessageDAO.shared.getMessage(messageId: self.messageId), (message.mediaUrl == nil || (message.mediaStatus != MediaStatus.DONE.rawValue && message.mediaStatus != MediaStatus.EXPIRED.rawValue)) else {
            return false
        }
        guard let attachmentId = message.content, !attachmentId.isEmpty else {
            return false
        }


        self.message = message
        switch MessageAPI.shared.getAttachment(id: attachmentId) {
        case let .success(attachmentResponse):
            guard downloadAttachment(attachResponse: attachmentResponse) else {
                return false
            }
        case let .failure(error):
            guard retry(error) else {
                return false
            }
        }
        return true
    }

    private func downloadAttachment(attachResponse: AttachmentResponse) -> Bool {
        guard let viewUrl = attachResponse.viewUrl, let downloadUrl = URL(string: viewUrl) else {
            return false
        }

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        var request = URLRequest(url: downloadUrl)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        task = session.downloadTask(with: request)
        task?.resume()
        session.finishTasksAndInvalidate()
        return true
    }

    override func taskFinished(data: Any?) {
        guard let location = data as? URL else {
            return
        }
        guard FileManager.default.fileSize(location.path) > 0, let mediaSize = message.mediaSize, let fileData = FileManager.default.contents(atPath: location.path) else {
            return
        }

        if message.category.hasPrefix("SIGNAL_") {
            guard let key = message.mediaKey, let digest = message.mediaDigest else {
                return
            }
            var error: NSError?
            let encryptedData = Cryptography.decryptAttachment(fileData, withKey: key, digest: digest, unpaddedSize: UInt32(mediaSize), error: &error)

            if let err = error {
                Bugsnag.notifyError(err)
                return
            }
            guard !encryptedData.isEmpty else {
                return
            }

            downloadFinished(data: encryptedData)
        } else {
            downloadFinished(data: fileData)
        }
    }

    func downloadFinished(data: Data) {
        let imagePath = MixinFile.chatPhotosUrl(imageName)
        do {
            try? FileManager.default.removeItem(atPath: imagePath.path)
            try data.write(to: imagePath)
            MessageDAO.shared.updateMediaMessage(messageId: messageId, mediaUrl: imageName, status: MediaStatus.DONE, conversationId: message.conversationId)
        } catch {
            Bugsnag.notifyError(error)
        }
    }

    override func downloadExpired() {
        MessageDAO.shared.updateMediaStatus(messageId: messageId, status: MediaStatus.EXPIRED, conversationId: message.conversationId)
    }

}

extension AttachmentDownloadJob: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !isFinished else {
            return
        }
        completionHandler(nil, nil, error)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        completionHandler(location, downloadTask.response, nil)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let change = ConversationChange(conversationId: message.conversationId,
                                        action: .updateDownloadProgress(messageId: messageId, progress: progress))
        NotificationCenter.default.postOnMain(name: .ConversationDidChange, object: change)
    }

}

