import Foundation
import Alamofire
import MixinServices

final class TranscriptAttachmentUploadJob: AsynchronousJob {
    
    enum Error: Swift.Error {
        case invalidUploadURL(String?)
        case requestFailed(Swift.Error)
        case missingMetadata(hasKey: Bool, hasDigest: Bool)
        case invalidJSON
    }
    
    private struct Metadata {
        let mediaKey: Data?
        let mediaDigest: Data?
        let attachmentId: String
    }
    
    private let jobIdToRemove: String
    private let maxNumberOfConcurrentUploadTask = 3
    private let lock = NSLock()
    private let isPlainTranscript: Bool
    
    private var message: Message
    private var childMessages: [TranscriptMessage] = []
    private var pendingRequests: [String: Request] = [:]
    private var loadingRequests: [String: Request] = [:]
    
    init(message: Message, jobIdToRemoveAfterFinished jobId: String) {
        self.message = message
        self.isPlainTranscript = message.category.hasPrefix("PLAIN_")
        self.jobIdToRemove = jobId
    }
    
    override func getJobId() -> String {
        return "transcript-upload-\(message.messageId)"
    }
    
    override func execute() -> Bool {
        let children = TranscriptMessageDAO.shared.childMessages(with: message.messageId)
        guard !children.isEmpty else {
            return false
        }
        for (index, child) in children.enumerated() {
            guard MessageCategory.allMediaCategoriesString.contains(child.category) else {
                continue
            }
            let areKeyDigestReady = isPlainTranscript || (!child.mediaDigest.isNilOrEmpty && !child.mediaKey.isNilOrEmpty)
            if let content = child.content,
               UUID(uuidString: content) != nil,
               areKeyDigestReady,
               child.mediaStatus == MediaStatus.DONE.rawValue,
               let createdAt = child.mediaCreatedAt?.toUTCDate(),
               abs(createdAt.timeIntervalSinceNow) < secondsPerDay
            {
                continue
            } else if let content = child.content,
                      let extra = AttachmentExtra.decode(from: content),
                      abs(extra.createdAt.toUTCDate().timeIntervalSinceNow) < secondsPerDay
            {
                child.content = extra.attachmentId
                continue
            } else if let mediaUrl = child.mediaUrl {
                let url = AttachmentContainer.url(transcriptId: message.messageId, filename: mediaUrl)
                let stream: InputStream?
                if isPlainTranscript {
                    stream = InputStream(url: url)
                } else {
                    stream = AttachmentEncryptingInputStream(url: url)
                }
                if let stream = stream, stream.streamError == nil {
                    let contentLength: Int
                    if let stream = stream as? AttachmentEncryptingInputStream {
                        contentLength = stream.contentLength
                    } else {
                        contentLength = Int(FileManager.default.fileSize(url.path))
                    }
                    let request = Request(childIndex: index, stream: stream, contentLength: contentLength)
                    if loadingRequests.count < maxNumberOfConcurrentUploadTask {
                        loadingRequests[child.messageId] = request
                    } else {
                        pendingRequests[child.messageId] = request
                    }
                    request.job = self
                } else {
                    child.content = nil
                }
            } else {
                child.content = nil
            }
        }
        self.childMessages = children
        if loadingRequests.isEmpty {
            finishMessageSending()
        } else {
            for request in loadingRequests.values {
                request.start()
            }
        }
        return true
    }
    
    override func cancel() {
        lock.lock()
        for request in loadingRequests.values {
            request.cancel()
        }
        lock.unlock()
        super.cancel()
    }
    
    private func request(_ request: Request, succeedWith metadata: Metadata, createdAt: String) {
        lock.lock()
        defer {
            lock.unlock()
        }
        let child = childMessages[request.childIndex]
        child.content = metadata.attachmentId
        child.mediaKey = metadata.mediaKey
        child.mediaDigest = metadata.mediaDigest
        child.mediaCreatedAt = createdAt
        loadingRequests[child.messageId] = nil
        TranscriptMessageDAO.shared.update(transcriptId: message.messageId,
                                           messageId: child.messageId,
                                           content: metadata.attachmentId,
                                           mediaKey: metadata.mediaKey,
                                           mediaDigest: metadata.mediaDigest,
                                           mediaStatus: MediaStatus.DONE.rawValue,
                                           mediaCreatedAt: createdAt)
        if loadingRequests.isEmpty && pendingRequests.isEmpty {
            finishMessageSending()
        } else if !pendingRequests.isEmpty {
            let (id, request) = pendingRequests.remove(at: pendingRequests.startIndex)
            loadingRequests[id] = request
            request.start()
        }
    }
    
    private func request(_ request: Request, failedWith error: Swift.Error) {
        lock.lock()
        defer {
            lock.unlock()
        }
        reporter.report(error: Error.requestFailed(error))
        finishJob()
    }
    
    private func finishMessageSending() {
        MessageDAO.shared.updateMediaStatus(messageId: message.messageId,
                                            status: .DONE,
                                            conversationId: message.conversationId)
        for child in childMessages {
            child.mediaUrl = nil
            child.mediaStatus = nil
        }
        do {
            let data = try JSONEncoder.default.encode(childMessages)
            guard let content = String(data: data, encoding: .utf8) else {
                throw Error.invalidJSON
            }
            SendMessageService.shared.sendMessage(message: message, data: content)
        } catch {
            Logger.general.error(category: "TranscriptAttachmentUploadJob", message: "Unable to encode child messages: \(error)")
            reporter.report(error: error)
        }
        finishJob()
        JobDAO.shared.removeJob(jobId: jobIdToRemove)
    }
    
}

extension TranscriptAttachmentUploadJob {
    
    private final class Request {
        
        let childIndex: Int
        let stream: InputStream
        let contentLength: Int
        
        weak var job: TranscriptAttachmentUploadJob?
        
        @Synchronized(value: nil)
        private var attachmentRequest: Alamofire.Request?
        @Synchronized(value: nil)
        private var uploadRequest: Alamofire.Request?
        
        init(childIndex: Int, stream: InputStream, contentLength: Int) {
            self.childIndex = childIndex
            self.stream = stream
            self.contentLength = contentLength
        }
        
        func start() {
            attachmentRequest = MessageAPI.requestAttachment(queue: .global()) { [weak self] (response) in
                guard let self = self else {
                    return
                }
                switch response {
                case .success(let resp):
                    self.upload(with: resp)
                case .failure(let error):
                    switch error {
                    case .httpTransport(.explicitlyCancelled):
                        break
                    default:
                        if error.worthRetrying {
                            DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
                                self?.start()
                            }
                        } else {
                            self.job?.request(self, failedWith: error)
                        }
                    }
                }
            }
        }
        
        func cancel() {
            attachmentRequest?.cancel()
            uploadRequest?.cancel()
        }
        
        private func upload(with attachmentResponse: AttachmentResponse) {
            guard let url = attachmentResponse.uploadUrl, var request = try? URLRequest(url: url, method: .put) else {
                job?.request(self, failedWith: Error.invalidUploadURL(attachmentResponse.uploadUrl))
                return
            }
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            request.setValue("\(contentLength)", forHTTPHeaderField: "Content-Length")
            request.setValue("public-read", forHTTPHeaderField: "x-amz-acl")
            request.setValue("Connection", forHTTPHeaderField: "close")
            request.cachePolicy = .reloadIgnoringCacheData
            request.httpBodyStream = stream
            AF.request(request).response(queue: .global()) { [weak self] uploadResponse in
                guard let self = self else {
                    return
                }
                switch uploadResponse.result {
                case .success:
                    if let error = self.stream.streamError {
                        self.job?.request(self, failedWith: error)
                    } else if let stream = self.stream as? AttachmentEncryptingInputStream {
                        if let key = stream.key, !key.isEmpty, let digest = stream.digest, !digest.isEmpty {
                            let metadata = Metadata(mediaKey: key,
                                                    mediaDigest: digest,
                                                    attachmentId: attachmentResponse.attachmentId)
                            let createdAt = attachmentResponse.createdAt ?? Date().toUTCString()
                            self.job?.request(self, succeedWith: metadata, createdAt: createdAt)
                        } else {
                            let error = Error.missingMetadata(hasKey: !stream.key.isNilOrEmpty,
                                                              hasDigest: !stream.digest.isNilOrEmpty)
                            self.job?.request(self, failedWith: error)
                        }
                    } else {
                        let metadata = Metadata(mediaKey: nil,
                                                mediaDigest: nil,
                                                attachmentId: attachmentResponse.attachmentId)
                        let createdAt = attachmentResponse.createdAt ?? Date().toUTCString()
                        self.job?.request(self, succeedWith: metadata, createdAt: createdAt)
                    }
                case .failure(let error):
                    switch error {
                    case .explicitlyCancelled:
                        break
                    default:
                        if error.worthRetrying {
                            DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
                                self?.upload(with: attachmentResponse)
                            }
                        } else {
                            self.job?.request(self, failedWith: error)
                        }
                    }
                }
            }
        }
        
    }
    
}
