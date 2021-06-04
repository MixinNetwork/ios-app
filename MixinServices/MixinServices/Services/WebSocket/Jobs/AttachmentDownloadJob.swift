import Foundation
import UIKit

open class AttachmentDownloadJob: AttachmentLoadingJob {
    
    public static let didFinishNotification = Notification.Name("one.mixin.services.AttachmentDownloadJob.DidFinish")
    
    private var stream: OutputStream?
    private var contentLength: Double?
    private var downloadedContentLength: Double = 0
    private var attachResponse: AttachmentResponse?
    private var owner: AttachmentOwner!
    
    private var originalPathExtension: String? {
        owner.mediaName?.pathExtension()?.lowercased()
    }
    
    private var mimeInferredPathExtension: String? {
        if let mimeType = owner.mediaMimeType?.lowercased() {
            return FileManager.default.pathExtension(mimeType: mimeType)?.lowercased()
        } else {
            return nil
        }
    }
    
    private lazy var fileName: String = {
        let extensionName: String?
        let category = owner.category
        if category.hasSuffix("_VIDEO") {
            extensionName = ExtensionName.mp4.rawValue
        } else if category.hasSuffix("_IMAGE") {
            extensionName = mimeInferredPathExtension
                ?? originalPathExtension
                ?? ExtensionName.jpeg.rawValue
        } else if category.hasSuffix("_AUDIO") {
            extensionName = ExtensionName.ogg.rawValue
        } else {
            extensionName = originalPathExtension ?? mimeInferredPathExtension
        }
        
        var filename = owner.messageId
        if let name = extensionName {
            filename += ".\(name)"
        }
        return filename
    }()
    
    private lazy var fileUrl: URL = {
        if let tid = transcriptId {
            return AttachmentContainer.url(transcriptId: tid, filename: fileName)
        } else {
            let category = AttachmentContainer.Category(messageCategory: owner.category) ?? .files
            return AttachmentContainer.url(for: category, filename: fileName)
        }
    }()
    
    public init(message: Message, jobId: String? = nil, isRecoverAttachment: Bool = false) {
        self.owner = .message(message)
        super.init(transcriptId: nil,
                   messageId: message.messageId,
                   jobId: jobId,
                   isRecoverAttachment: isRecoverAttachment)
    }
    
    public override init(
        transcriptId: String? = nil,
        messageId: String,
        jobId: String? = nil,
        isRecoverAttachment: Bool = false
    ) {
        super.init(transcriptId: transcriptId,
                   messageId: messageId,
                   jobId: jobId,
                   isRecoverAttachment: isRecoverAttachment)
    }
    
    open class func jobId(transcriptId: String?, messageId: String) -> String {
        if let tid = transcriptId {
            return "attachment-download-\(tid)-\(messageId)"
        } else {
            return "attachment-download-\(messageId)"
        }
    }
    
    override open func getJobId() -> String {
        Self.jobId(transcriptId: transcriptId, messageId: messageId)
    }
    
    override open func execute() -> Bool {
        guard let attachmentId = validateAttachmentOwner() else {
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
            case .failure(.notFound):
                downloadExpired()
                removeJob()
                finishJob()
                return false
            case let .failure(error) where error.worthRetrying:
                checkNetworkAndWebSocket()
            case let .failure(error):
                return false
            }
        } while LoginManager.shared.isLoggedIn && !isCancelled
        return false
    }
    
    override open func taskFinished() {
        if let error = stream?.streamError {
            try? FileManager.default.removeItem(at: fileUrl)
            reporter.report(error: error)
            updateMediaMessage(mediaUrl: fileName, status: .CANCELED)
        } else {
            if owner.category.hasSuffix("_VIDEO") {
                let thumbnail = UIImage(withFirstFrameOfVideoAtURL: fileUrl)
                let thumbnailURL: URL
                if let tid = transcriptId {
                    thumbnailURL = AttachmentContainer.videoThumbnailURL(transcriptId: tid, videoFilename: fileName)
                } else {
                    thumbnailURL = AttachmentContainer.videoThumbnailURL(videoFilename: fileName)
                }
                thumbnail?.saveToFile(path: thumbnailURL)
            }
            let content: String? = {
                guard let response = attachResponse else {
                    return nil
                }
                guard let createdAt = response.createdAt else {
                    return nil
                }
                let extra = AttachmentExtra(attachmentId: response.attachmentId, createdAt: createdAt)
                guard let json = try? JSONEncoder.default.encode(extra) else {
                    return nil
                }
                return json.base64EncodedString()
            }()
            updateMediaMessage(mediaUrl: fileName, status: .DONE, content: content)
            let userInfo = [
                Self.UserInfoKey.transcriptId: transcriptId,
                Self.UserInfoKey.messageId: messageId,
                Self.UserInfoKey.mediaURL: fileName
            ]
            NotificationCenter.default.post(onMainThread: Self.didFinishNotification, object: self, userInfo: userInfo)
            removeJob()
        }
    }
    
    override open func downloadExpired() {
        switch owner! {
        case .message(let message):
            MessageDAO.shared.updateMediaStatus(messageId: messageId, status: .EXPIRED, conversationId: message.conversationId)
        case .transcriptMessage(let message):
            if let tid = transcriptId {
                TranscriptMessageDAO.shared.updateMediaStatus(.EXPIRED, transcriptId: tid, messageId: messageId)
            }
        }
    }
    
    func updateMediaMessage(mediaUrl: String, status: MediaStatus, content: String? = nil) {
        switch owner! {
        case .message(let message):
            MessageDAO.shared.updateMediaMessage(messageId: messageId,
                                                 mediaUrl: fileName,
                                                 status: status,
                                                 conversationId: message.conversationId,
                                                 content: content)
        case .transcriptMessage(let message):
            TranscriptMessageDAO.shared.update(transcriptId: message.transcriptId,
                                               messageId: message.messageId,
                                               mediaStatus: status,
                                               mediaUrl: fileName)
        }
    }
    
}

extension AttachmentDownloadJob: URLSessionDataDelegate {
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Swift.Void) {
        contentLength = Double(response.expectedContentLength)
        completionHandler(.allow)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        data.withUnsafeUInt8Pointer {
            _ = stream?.write($0!, maxLength: data.count)
        }
        if let contentLength = contentLength {
            downloadedContentLength += Double(data.count)
            var userInfo: [String: Any] = [
                UserInfoKey.progress: downloadedContentLength / contentLength,
                UserInfoKey.messageId: messageId
            ]
            if let tid = transcriptId {
                userInfo[UserInfoKey.transcriptId] = tid
            }
            if case .message(let message) = owner {
                userInfo[UserInfoKey.conversationId] = message.conversationId
            }
            NotificationCenter.default.post(onMainThread: Self.progressNotification,
                                            object: self,
                                            userInfo: userInfo)
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        stream?.close()
        completionHandler(nil, task.response, error)
    }
    
}

extension AttachmentDownloadJob {
    
    private func validateAttachmentOwner() -> String? {
        guard !messageId.isEmpty else {
            return nil
        }
        let owner: AttachmentOwner
        if let o = self.owner {
            owner = o
        } else {
            if let tid = transcriptId {
                guard let transcriptMessage = TranscriptMessageDAO.shared.transcriptMessage(transcriptId: tid, messageId: messageId) else {
                    return nil
                }
                owner = .transcriptMessage(transcriptMessage)
            } else {
                guard let message = MessageDAO.shared.getMessage(messageId: messageId) else {
                    return nil
                }
                owner = .message(message)
            }
        }
        guard owner.category != MessageCategory.MESSAGE_RECALL.rawValue else {
            return nil
        }
        guard let attachmentId = owner.content, !attachmentId.isEmpty else {
            return nil
        }
        guard UUID(uuidString: attachmentId) != nil else {
            let log = """
                [AttachmentDownloadJob] Message with id: \(owner.messageId), category: \(owner.category), mediaUrl:\(owner.mediaUrl), mediaStatus:\(owner.mediaStatus ?? "")
                    has an invalid content: \(attachmentId)
            """
            Logger.write(errorMsg: log)
            return nil
        }
        guard !(jobId?.isEmpty ?? true) || owner.mediaUrl == nil || (owner.mediaStatus != MediaStatus.DONE.rawValue && owner.mediaStatus != MediaStatus.READ.rawValue && owner.category != MessageCategory.MESSAGE_RECALL.rawValue) else {
            return nil
        }
        self.owner = owner
        return attachmentId
    }
    
    private func downloadAttachment(attachResponse: AttachmentResponse) -> Bool {
        guard let viewUrl = attachResponse.viewUrl, let downloadUrl = URL(string: viewUrl) else {
            return false
        }
        self.attachResponse = attachResponse
        
        let encrypts = owner.category.hasPrefix("SIGNAL_")
        if encrypts {
            guard let key = owner.mediaKey, let digest = owner.mediaDigest else {
                return false
            }
            stream = AttachmentDecryptingOutputStream(url: fileUrl, key: key, digest: digest)
        } else {
            stream = OutputStream(url: fileUrl, append: false)
        }
        
        guard let stream = stream else {
            let error: MixinServicesError = encrypts ? .initDecryptingOutputStream : .initOutputStream
            reporter.report(error: error)
            return false
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
    
}
