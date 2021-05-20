import Foundation
import Alamofire
import MixinServices

final class TranscriptAttachmentUploadJob: AsynchronousJob {
    
    enum Error: Swift.Error {
        case invalidUploadURL(String?)
        case streamFailed(Swift.Error)
        case missingMetadata(hasKey: Bool, hasDigest: Bool)
        case encodeAttachmentContent(Swift.Error)
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
    private var children: [TranscriptMessage] = []
    private var pendingRequests: [String: Request] = [:]
    private var loadingRequests: [String: Request] = [:]
    
    init(message: Message, jobIdToRemoveAfterFinished jobId: String) {
        self.message = message
        self.jobIdToRemove = jobId
    }
    
    override func getJobId() -> String {
        return "transcript-atmt-\(message.messageId)"
    }
    
    override func execute() -> Bool {
        guard
            let json = message.content?.data(using: .utf8),
            let children = try? JSONDecoder.snakeCase.decode([TranscriptMessage].self, from: json)
        else {
            return false
        }
        for (index, child) in children.enumerated() {
            guard child.category.includesAttachment else {
                continue
            }
            if let createdAt = child.attachmentCreatedAt?.toUTCDate(), abs(createdAt.timeIntervalSinceNow) < secondsPerDay {
                continue
            } else if let mediaUrl = child.mediaUrl {
                let url = AttachmentContainer.url(forTranscriptMessageWith: message.messageId, filename: mediaUrl)
                if let stream = AttachmentEncryptingInputStream(url: url), stream.streamError == nil {
                    let request = Request(childIndex: index, stream: stream)
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
        self.children = children
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
        let child = children[request.childIndex]
        child.content = metadata.attachmentId
        child.mediaKey = metadata.mediaKey
        child.mediaDigest = metadata.mediaDigest
        child.mediaStatus = MediaStatus.DONE.rawValue
        child.attachmentCreatedAt = createdAt
        loadingRequests[child.messageId] = nil
        do {
            let json = try JSONEncoder.snakeCase.encode(children)
            let content = String(data: json, encoding: .utf8) ?? ""
            message.content = content
            MessageDAO.shared.update(content: content,
                                     forMessageWith: message.messageId)
            if pendingRequests.isEmpty {
                finishMessageSending()
            } else {
                let (id, request) = pendingRequests.remove(at: pendingRequests.startIndex)
                loadingRequests[id] = request
                request.start()
            }
        } catch {
            reporter.report(error: Error.encodeAttachmentContent(error))
            finishJob()
        }
    }
    
    private func request(_ request: Request, failedWith error: Swift.Error) {
        lock.lock()
        defer {
            lock.unlock()
        }
        reporter.report(error: Error.encodeAttachmentContent(error))
        finishJob()
    }
    
    private func finishMessageSending() {
        MessageDAO.shared.updateMediaStatus(messageId: message.messageId,
                                            status: .DONE,
                                            conversationId: message.conversationId)
        SendMessageService.shared.sendMessage(message: message, data: message.content)
        finishJob()
        JobDAO.shared.removeJob(jobId: jobIdToRemove)
    }
    
}

extension TranscriptAttachmentUploadJob {
    
    private final class Request {
        
        let childIndex: Int
        let stream: AttachmentEncryptingInputStream
        
        weak var job: TranscriptAttachmentUploadJob?
        
        @Synchronized(value: nil)
        private var attachmentRequest: Alamofire.Request?
        @Synchronized(value: nil)
        private var uploadRequest: Alamofire.Request?
        
        init(childIndex: Int, stream: AttachmentEncryptingInputStream) {
            self.childIndex = childIndex
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
