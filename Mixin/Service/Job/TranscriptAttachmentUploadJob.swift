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
        let mediaKey: Data
        let mediaDigest: Data
        let attachmentId: String
    }
    
    private let jobIdToRemove: String
    private let maxNumberOfConcurrentUploadTask = 3
    private let lock = NSLock()
    
    private var message: Message
    private var descendants: [TranscriptMessage] = []
    private var pendingRequests: [String: Request] = [:]
    private var loadingRequests: [String: Request] = [:]
    
    init(message: Message, jobIdToRemoveAfterFinished jobId: String) {
        self.message = message
        self.jobIdToRemove = jobId
    }
    
    override func getJobId() -> String {
        return "transcript-upload-\(message.messageId)"
    }
    
    override func execute() -> Bool {
        let descendants = TranscriptMessageDAO.shared.descendantMessages(with: message.messageId)
        guard !descendants.isEmpty else {
            return false
        }
        for (index, descendant) in descendants.enumerated() {
            guard descendant.category.includesAttachment else {
                continue
            }
            if let content = descendant.content,
               UUID(uuidString: content) != nil,
               descendant.mediaKey != nil,
               descendant.mediaDigest != nil,
               descendant.mediaStatus == MediaStatus.DONE.rawValue,
               let createdAt = descendant.mediaCreatedAt?.toUTCDate(),
               abs(createdAt.timeIntervalSinceNow) < secondsPerDay
            {
                continue
            } else if let mediaUrl = descendant.mediaUrl {
                let url = AttachmentContainer.url(transcriptId: message.messageId, filename: mediaUrl)
                if let stream = AttachmentEncryptingInputStream(url: url), stream.streamError == nil {
                    let request = Request(descendantIndex: index, stream: stream)
                    if loadingRequests.count < maxNumberOfConcurrentUploadTask {
                        loadingRequests[descendant.messageId] = request
                    } else {
                        pendingRequests[descendant.messageId] = request
                    }
                    request.job = self
                } else {
                    descendant.content = nil
                }
            } else {
                descendant.content = nil
            }
        }
        self.descendants = descendants
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
        let descendant = descendants[request.descendantIndex]
        descendant.content = metadata.attachmentId
        descendant.mediaKey = metadata.mediaKey
        descendant.mediaDigest = metadata.mediaDigest
        descendant.mediaCreatedAt = createdAt
        loadingRequests[descendant.messageId] = nil
        TranscriptMessageDAO.shared.update(transcriptId: message.messageId,
                                           messageId: descendant.messageId,
                                           content: metadata.attachmentId,
                                           mediaKey: metadata.mediaKey,
                                           mediaDigest: metadata.mediaDigest,
                                           mediaStatus: MediaStatus.DONE.rawValue,
                                           mediaCreatedAt: createdAt)
        if pendingRequests.isEmpty {
            finishMessageSending()
        } else {
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
        for descendant in descendants {
            descendant.mediaUrl = nil
            descendant.mediaStatus = nil
        }
        do {
            let data = try JSONEncoder.default.encode(descendants)
            guard let content = String(data: data, encoding: .utf8) else {
                throw Error.invalidJSON
            }
            SendMessageService.shared.sendMessage(message: message, data: content)
        } catch {
            Logger.write(error: error)
            reporter.report(error: error)
        }
        finishJob()
        JobDAO.shared.removeJob(jobId: jobIdToRemove)
    }
    
}

extension TranscriptAttachmentUploadJob {
    
    private final class Request {
        
        let descendantIndex: Int
        let stream: AttachmentEncryptingInputStream
        
        weak var job: TranscriptAttachmentUploadJob?
        
        @Synchronized(value: nil)
        private var attachmentRequest: Alamofire.Request?
        @Synchronized(value: nil)
        private var uploadRequest: Alamofire.Request?
        
        init(descendantIndex: Int, stream: AttachmentEncryptingInputStream) {
            self.descendantIndex = descendantIndex
            self.stream = stream
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
            request.setValue("\(stream.contentLength)", forHTTPHeaderField: "Content-Length")
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
                    } else if let key = self.stream.key, let digest = self.stream.digest {
                        let metadata = Metadata(mediaKey: key,
                                                mediaDigest: digest,
                                                attachmentId: attachmentResponse.attachmentId)
                        let createdAt = attachmentResponse.createdAt ?? Date().toUTCString()
                        self.job?.request(self, succeedWith: metadata, createdAt: createdAt)
                    } else {
                        let error = Error.missingMetadata(hasKey: self.stream.key != nil,
                                                          hasDigest: self.stream.digest != nil)
                        self.job?.request(self, failedWith: error)
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
