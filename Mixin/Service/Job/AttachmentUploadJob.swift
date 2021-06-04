import Foundation
import UIKit
import MixinServices

class AttachmentUploadJob: AttachmentLoadingJob {
    
    private var stream: InputStream?
    
    var message: Message!
    var attachResponse: AttachmentResponse?
    
    var fileUrl: URL? {
        guard let mediaUrl = message.mediaUrl, !mediaUrl.isEmpty else {
            return nil
        }
        return AttachmentContainer.url(for: .photos, filename: mediaUrl)
    }
    
    public init(message: Message, jobId: String? = nil) {
        self.message = message
        super.init(transcriptId: nil,
                   messageId: message.messageId,
                   jobId: jobId,
                   isRecoverAttachment: false)
    }
    
    class func jobId(messageId: String) -> String {
        return "attachment-upload-\(messageId)"
    }
    
    override func getJobId() -> String {
        return Self.jobId(messageId: message.messageId)
    }
    
    override func execute() -> Bool {
        guard !self.message.messageId.isEmpty, !isCancelled else {
            removeJob()
            return false
        }
        
        let isAttachmentMetadataReady = message.category.hasPrefix("PLAIN_")
            || (message.category.hasPrefix("SIGNAL_") && message.mediaKey != nil && message.mediaDigest != nil)
        if let content = message.content,
           !content.isEmpty,
           isAttachmentMetadataReady,
           let data = Data(base64Encoded: content),
           let attachmentExtra = try? JSONDecoder.default.decode(AttachmentExtra.self, from: data),
           UUID(uuidString: attachmentExtra.attachmentId) != nil,
           !attachmentExtra.createdAt.isEmpty,
           abs(attachmentExtra.createdAt.toUTCDate().timeIntervalSinceNow) < secondsPerDay {
            uploadFinished(attachmentId: attachmentExtra.attachmentId, key: message.mediaKey, digest: message.mediaDigest, createdAt: attachmentExtra.createdAt)
            finishJob()
            return true
        }
        
        repeat {
            switch MessageAPI.requestAttachment() {
            case let .success(attachResponse):
                self.attachResponse = attachResponse
                guard uploadAttachment(attachResponse: attachResponse) else {
                    removeJob()
                    return false
                }
                return true
            case let .failure(error):
                if error.worthRetrying {
                    checkNetworkAndWebSocket()
                } else {
                    return false
                }
            }
        } while LoginManager.shared.isLoggedIn && !isCancelled
        return false
    }
    
    private func uploadAttachment(attachResponse: AttachmentResponse) -> Bool {
        guard let uploadUrl = attachResponse.uploadUrl, !uploadUrl.isEmpty, var request = try? URLRequest(url: uploadUrl, method: .put) else {
            return false
        }
        guard let fileUrl = fileUrl else {
            MessageDAO.shared.deleteMessage(id: messageId)
            return false
        }
        
        let needsEncryption = message.category.hasPrefix("SIGNAL_")
        let contentLength: Int
        do {
            if needsEncryption {
                if let inputStream = AttachmentEncryptingInputStream(url: fileUrl) {
                    contentLength = inputStream.contentLength
                    stream = inputStream
                } else {
                    let attrs = try FileManager.default.attributesOfItem(atPath: fileUrl.path)
                    let error = MixinServicesError.initInputStream(url: fileUrl,
                                                                   isEncrypted: needsEncryption,
                                                                   fileAttributes: attrs,
                                                                   error: nil)
                    reporter.report(error: error)
                    return false
                }
            } else {
                stream = InputStream(url: fileUrl)
                contentLength = Int(FileManager.default.fileSize(fileUrl.path))
                if stream == nil || contentLength <= 0 {
                    let attrs = try FileManager.default.attributesOfItem(atPath: fileUrl.path)
                    let error = MixinServicesError.initInputStream(url: fileUrl,
                                                                   isEncrypted: needsEncryption,
                                                                   fileAttributes: attrs,
                                                                   error: nil)
                    reporter.report(error: error)
                    return false
                }
            }
        } catch let underlying {
            let error = MixinServicesError.initInputStream(url: fileUrl,
                                                           isEncrypted: needsEncryption,
                                                           fileAttributes: nil,
                                                           error: underlying)
            reporter.report(error: error)
            return false
        }
        
        guard let inputStream = stream, contentLength > 0 else {
            return false
        }
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("\(contentLength)", forHTTPHeaderField: "Content-Length")
        request.setValue("public-read", forHTTPHeaderField: "x-amz-acl")
        request.setValue("Connection", forHTTPHeaderField: "close")
        request.cachePolicy = .reloadIgnoringCacheData
        request.httpBodyStream = inputStream
        
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        task = session.dataTask(with: request, completionHandler: completionHandler)
        task?.resume()
        session.finishTasksAndInvalidate()
        return true
    }
    
    override func taskFinished() {
        guard let attachResponse = self.attachResponse else {
            return
        }
        let key = (stream as? AttachmentEncryptingInputStream)?.key
        let digest = (stream as? AttachmentEncryptingInputStream)?.digest
        uploadFinished(attachmentId: attachResponse.attachmentId, key: key, digest: digest, createdAt: attachResponse.createdAt)
    }
    
    private func uploadFinished(attachmentId: String, key: Data?, digest: Data?, createdAt: String?) {
        let transferMediaData = TransferAttachmentData(key: key,
                                                       digest: digest,
                                                       attachmentId: attachmentId,
                                                       mimeType: message.mediaMimeType ?? "",
                                                       width: message.mediaWidth,
                                                       height: message.mediaHeight,
                                                       size: message.mediaSize ?? 0,
                                                       thumbnail: message.thumbImage,
                                                       name: message.name,
                                                       duration: message.mediaDuration,
                                                       waveform: message.mediaWaveform,
                                                       createdAt: createdAt)
        let content = (try? JSONEncoder.default.encode(transferMediaData).base64EncodedString()) ?? ""
        message.content = content
        message.mediaKey = key
        message.mediaDigest = digest
        MessageDAO.shared.updateMessageContentAndMediaStatus(content: content, mediaStatus: .DONE, key: key, digest: digest, messageId: message.messageId, conversationId: message.conversationId)
        
        SendMessageService.shared.sendMessage(message: message, data: content)
        removeJob()
    }
}

extension AttachmentUploadJob: URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let userInfo: [String: Any] = [
            Self.UserInfoKey.progress: Double(totalBytesSent) / Double(totalBytesExpectedToSend),
            Self.UserInfoKey.conversationId: message.conversationId,
            Self.UserInfoKey.messageId: message.messageId
        ]
        NotificationCenter.default.post(onMainThread: Self.progressNotification,
                                        object: self,
                                        userInfo: userInfo)
    }
    
}
