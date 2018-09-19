import Foundation
import UIKit
import Bugsnag

class AttachmentDownloadJob: UploadOrDownloadJob {

    private(set) var stream: OutputStream!
    
    private var contentLength: Double?
    private var downloadedContentLength: Double = 0
    private var mediaMimeType: String?

    internal var fileName: String {
        return "\(message.messageId).\(FileManager.default.pathExtension(mimeType: message.mediaMimeType?.lowercased() ?? ExtensionName.jpeg.rawValue))"
    }
    
    internal var fileUrl: URL {
        return MixinFile.url(ofChatDirectory: .photos, filename: fileName)
    }
    
    init(messageId: String, mediaMimeType: String?) {
        super.init(messageId: messageId)
        self.mediaMimeType = mediaMimeType
    }

    class func jobId(messageId: String) -> String {
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
        repeat {
            switch MessageAPI.shared.getAttachment(id: attachmentId) {
            case let .success(attachmentResponse):
                guard downloadAttachment(attachResponse: attachmentResponse) else {
                    return false
                }
                return true
            case let .failure(error):
                guard error.isClientError || error.isServerError else {
                    return false
                }
                checkNetworkAndWebSocket()
                Thread.sleep(forTimeInterval: 2)
            }
        } while AccountAPI.shared.didLogin && !isCancelled
        return false
    }

    private func downloadAttachment(attachResponse: AttachmentResponse) -> Bool {
        guard let viewUrl = attachResponse.viewUrl, let downloadUrl = URL(string: viewUrl) else {
            return false
        }

        if message.category.hasPrefix("SIGNAL_") {
            guard let key = message.mediaKey, let digest = message.mediaDigest else {
                return false
            }
            stream = AttachmentDecryptingOutputStream(url: fileUrl, key: key, digest: digest)
            if stream == nil {
                UIApplication.trackError(String(describing: type(of: self)), action: "AttachmentDecryptingOutputStream init failed")
                return false
            }
        } else {
            stream = OutputStream(url: fileUrl, append: false)
            if stream == nil {
                UIApplication.trackError(String(describing: type(of: self)), action: "OutputStream init failed")
                return false
            }
        }
        
        downloadedContentLength = 0
        stream.open()
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        var request = URLRequest(url: downloadUrl)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        task = session.dataTask(with: request)
        task?.resume()
        session.finishTasksAndInvalidate()
        return true
    }

    override func taskFinished() {
        if let error = stream.streamError {
            try? FileManager.default.removeItem(at: fileUrl)
            Bugsnag.notifyError(error)
            MessageDAO.shared.updateMediaMessage(messageId: messageId, mediaUrl: fileName, status: .CANCELED, conversationId: message.conversationId)
        } else {
            MessageDAO.shared.updateMediaMessage(messageId: messageId, mediaUrl: fileName, status: .DONE, conversationId: message.conversationId)
        }
    }
    
    override func downloadExpired() {
        MessageDAO.shared.updateMediaStatus(messageId: messageId, status: .EXPIRED, conversationId: message.conversationId)
    }

}

extension AttachmentDownloadJob: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Swift.Void) {
        contentLength = Double(response.expectedContentLength)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        _ = data.withUnsafeBytes {
            stream.write($0, maxLength: data.count)
        }
        if let contentLength = contentLength {
            downloadedContentLength += Double(data.count)
            let progress = downloadedContentLength / contentLength
            let change = ConversationChange(conversationId: message.conversationId,
                                            action: .updateDownloadProgress(messageId: messageId, progress: progress))
            NotificationCenter.default.postOnMain(name: .ConversationDidChange, object: change)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        stream.close()
        completionHandler(nil, task.response, error)
    }

}

