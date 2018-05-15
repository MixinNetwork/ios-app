import Foundation
import Bugsnag

class UploadOrDownloadJob: AsynchronousJob {

    internal let messageId: String
    internal var message: Message!
    internal var task: URLSessionTask?

    internal lazy var completionHandler = { [weak self] (data: Any?, response: URLResponse?, error: Error?) in
        guard let weakSelf = self else {
            return
        }
        if weakSelf.isCancelled {
            weakSelf.finishJob()
            return
        } else if let err = error {
            if weakSelf.retry(err) {
                return
            }
            weakSelf.finishJob()
            return
        }
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        guard statusCode != 404 else {
            weakSelf.downloadExpired()
            weakSelf.finishJob()
            return
        }
        guard statusCode == 200 else {
            UIApplication.trackError("UploadOrDownloadJob", action: "completionHandler", userInfo: ["statusCode": "\(statusCode ?? 0)"])
            if weakSelf.retry() {
                return
            }
            weakSelf.finishJob()
            return
        }

        weakSelf.taskFinished()
        weakSelf.finishJob()
    }

    init(messageId: String) {
        self.messageId = messageId
    }

    override func cancel() {
        task?.cancel()
        super.cancel()
    }

    internal func downloadExpired() {

    }

    internal func retry(_ error: Error) -> Bool {
        guard !isCancelled else {
            finishJob()
            return false
        }
        guard (error.errorCode != 404 && error.errorCode != 401) else {
            finishJob()
            return false
        }
        guard canTryAgain(error: error) else {
            if error.errorCode != NSURLErrorTimedOut {
                Bugsnag.notifyError(error)
            }
            finishJob()
            return false
        }

        checkNetworkAndWebSocket()

        Thread.sleep(forTimeInterval: 2)
        if !isCancelled {
            if !execute() {
                finishJob()
            }
            return true
        }
        return false
    }

    internal func retry() -> Bool {
        checkNetworkAndWebSocket()

        Thread.sleep(forTimeInterval: 2)
        if !isCancelled {
            if !execute() {
                finishJob()
            }
            return true
        }
        return false
    }

    func taskFinished() {

    }

}
