import Foundation
import UIKit

open class AttachmentDownloadJob: UploadOrDownloadJob {
    
    private(set) var stream: OutputStream!
    
    private var contentLength: Double?
    private var downloadedContentLength: Double = 0
    
    internal var fileName: String {
        
        var originalPathExtension: String? {
            message.name?.pathExtension()?.lowercased()
        }
        
        var mimeInferredPathExtension: String? {
            if let mimeType = message.mediaMimeType?.lowercased() {
                return FileManager.default.pathExtension(mimeType: mimeType)?.lowercased()
            } else {
                return nil
            }
        }
        
        let extensionName: String?
        if message.category.hasSuffix("_VIDEO") {
            extensionName = ExtensionName.mp4.rawValue
        } else if message.category.hasSuffix("_IMAGE") {
            extensionName = mimeInferredPathExtension
                ?? originalPathExtension
                ?? ExtensionName.jpeg.rawValue
        } else if message.category.hasSuffix("_AUDIO") {
            extensionName = ExtensionName.ogg.rawValue
        } else {
            extensionName = originalPathExtension ?? mimeInferredPathExtension
        }
        
        var filename = message.messageId
        if let name = extensionName {
            filename += ".\(name)"
        }
        return filename
    }
    
    internal var fileUrl: URL {
        return AttachmentContainer.url(for: .photos, filename: fileName)
    }

    open class func jobId(messageId: String) -> String {
        return "attachment-download-\(messageId)"
    }
    
    open class func jobId(category: String, messageId: String) -> String {
        if category.hasSuffix("_IMAGE") {
            return AttachmentDownloadJob.jobId(messageId: messageId)
        } else if category.hasSuffix("_DATA") {
            return FileDownloadJob.jobId(messageId: messageId)
        } else if category.hasSuffix("_AUDIO") {
            return AudioDownloadJob.jobId(messageId: messageId)
        } else if category.hasSuffix("_VIDEO") {
            return VideoDownloadJob.jobId(messageId: messageId)
        }
        return ""
    }
    
    override open func getJobId() -> String {
        return AttachmentDownloadJob.jobId(messageId: messageId)
    }
    
    override open func execute() -> Bool {
        guard let attachmentId = validAttachmentMessage() else {
            removeJob()
            return false
        }
        repeat {
            switch MessageAPI.getAttachment(id: attachmentId) {
            case let .success(attachmentResponse):
                guard downloadAttachment(attachResponse: attachmentResponse) else {
                    removeJob()
                    return false
                }
                return true
            case .failure(.endpointNotFound):
                downloadExpired()
                removeJob()
                finishJob()
                return false
            case let .failure(error) where !error.worthRetrying:
                return false
            case let .failure(error):
                checkNetworkAndWebSocket()
            }
        } while LoginManager.shared.isLoggedIn && !isCancelled
        return false
    }

    private func validAttachmentMessage() -> String? {
        guard !messageId.isEmpty else {
            return nil
        }
        guard let message = self.message ?? MessageDAO.shared.getMessage(messageId: messageId) else {
            return nil
        }
        guard message.category != MessageCategory.MESSAGE_RECALL.rawValue else {
            return nil
        }
        guard let attachmentId = message.content, !attachmentId.isEmpty else {
            return nil
        }
        guard UUID(uuidString: attachmentId) != nil else {
            Logger.write(errorMsg: "[AttachmentDownloadJob][\(message.category)][\(message.messageId)]...attachment id is not uuid...mediaUrl:\(message.mediaUrl)...mediaStatus:\(message.mediaStatus ?? "")...attachmentId:\(attachmentId)")
            return nil
        }
        guard !(jobId?.isEmpty ?? true) || message.mediaUrl == nil || (message.mediaStatus != MediaStatus.DONE.rawValue && message.mediaStatus != MediaStatus.READ.rawValue && message.category != MessageCategory.MESSAGE_RECALL.rawValue) else {
            return nil
        }

        self.message = message
        return attachmentId
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
                reporter.report(error: MixinServicesError.initDecryptingOutputStream)
                return false
            }
        } else {
            stream = OutputStream(url: fileUrl, append: false)
            if stream == nil {
                reporter.report(error: MixinServicesError.initOutputStream)
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
    
    override open func taskFinished() {
        if let error = stream.streamError {
            try? FileManager.default.removeItem(at: fileUrl)
            reporter.report(error: error)
            MessageDAO.shared.updateMediaMessage(messageId: messageId, mediaUrl: fileName, status: .CANCELED, conversationId: message.conversationId)
        } else {
            MessageDAO.shared.updateMediaMessage(messageId: messageId, mediaUrl: fileName, status: .DONE, conversationId: message.conversationId)
            removeJob()
        }
    }
    
    override open func downloadExpired() {
        MessageDAO.shared.updateMediaStatus(messageId: messageId, status: .EXPIRED, conversationId: message.conversationId)
    }
}

extension AttachmentDownloadJob: URLSessionDataDelegate {
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Swift.Void) {
        contentLength = Double(response.expectedContentLength)
        completionHandler(.allow)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        data.withUnsafeUInt8Pointer {
            _ = stream.write($0!, maxLength: data.count)
        }
        if let contentLength = contentLength {
            downloadedContentLength += Double(data.count)
            let progress = downloadedContentLength / contentLength
            let change = ConversationChange(conversationId: message.conversationId,
                                            action: .updateDownloadProgress(messageId: messageId, progress: progress))
            NotificationCenter.default.postOnMain(name: .ConversationDidChange, object: change)
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        stream.close()
        completionHandler(nil, task.response, error)
    }
    
}
