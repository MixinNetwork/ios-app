import Foundation

open class AttachmentLoadingJob: AsynchronousJob {
    
    public enum UserInfoKey {
        public static let progress = "prog"
        public static let conversationId = "cid"
        public static let transcriptId = "tid"
        public static let messageId = "mid"
        public static let mediaURL = "url"
    }
    
    public static let progressNotification = Notification.Name("one.mixin.messenger.AttachmentLoadingJob.Progress")
    
    public let transcriptId: String?
    public let messageId: String
    public let isRecoverAttachment: Bool
    
    public var task: URLSessionTask?
    public var jobId: String?
    
    public lazy var completionHandler = { [weak self] (data: Any?, response: URLResponse?, error: Error?) in
        guard let weakSelf = self else {
            return
        }
        if weakSelf.isCancelled || !LoginManager.shared.isLoggedIn {
            weakSelf.finishJob()
            return
        } else if let error = error {
            let nsError = error as NSError
            let connectionErrors = [NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost]
            let isConnectionError = nsError.domain == NSURLErrorDomain && connectionErrors.contains(nsError.code)
            if isConnectionError, weakSelf.retry() {
                return
            } else {
                weakSelf.finishJob()
                return
            }
        }
        
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        guard statusCode != 404 else {
            weakSelf.downloadExpired()
            weakSelf.removeJob()
            weakSelf.finishJob()
            return
        }
        guard statusCode == 200 else {
            if weakSelf.retry() {
                return
            }
            weakSelf.finishJob()
            return
        }
        
        weakSelf.taskFinished()
        weakSelf.finishJob()
    }
    
    public init(
        transcriptId: String? = nil,
        messageId: String,
        jobId: String? = nil,
        isRecoverAttachment: Bool = false
    ) {
        self.transcriptId = transcriptId
        self.messageId = messageId
        self.jobId = jobId
        self.isRecoverAttachment = isRecoverAttachment
    }
    
    override open func cancel() {
        task?.cancel()
        super.cancel()
    }
    
    open func downloadExpired() {
        
    }
    
    private func retry() -> Bool {
        checkNetworkAndWebSocket()

        if !isCancelled {
            if !execute() {
                finishJob()
            }
            return true
        }
        return false
    }
    
    open func taskFinished() {

    }

    public func removeJob() {
        guard let jobId = self.jobId, !jobId.isEmpty else {
            return
        }

        JobDAO.shared.removeJob(jobId: jobId)
    }
    
}
