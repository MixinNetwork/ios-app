import Foundation

open class UploadOrDownloadJob: AsynchronousJob {
    
    public let messageId: String
    public var message: Message!
    public var task: URLSessionTask?
    internal var jobId: String?
    public private(set) var isRecoverAttachment = false
    
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
    
    public init(messageId: String) {
        self.messageId = messageId
    }

    public init(message: Message, jobId: String? = nil, isRecoverAttachment: Bool = false) {
        self.messageId = message.messageId
        self.message = message
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
