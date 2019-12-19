import Foundation

class UploadOrDownloadJob: AsynchronousJob {

    let messageId: String
    var message: Message!
    var task: URLSessionTask?

    lazy var completionHandler = { [weak self] (data: Any?, response: URLResponse?, error: Error?) in
        guard let weakSelf = self else {
            return
        }
        if weakSelf.isCancelled || !AccountAPI.shared.didLogin {
            weakSelf.finishJob()
            return
        } else if let err = error {
            switch err.errorCode {
            case NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost:
                if weakSelf.retry() {
                    return
                }
                weakSelf.finishJob()
                return
            default:
                weakSelf.finishJob()
                return
            }
        }

        let statusCode = (response as? HTTPURLResponse)?.statusCode
        guard statusCode != 404 else {
            weakSelf.downloadExpired()
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

    init(messageId: String) {
        self.messageId = messageId
    }

    override func cancel() {
        task?.cancel()
        super.cancel()
    }

    func downloadExpired() {

    }

    private func retry() -> Bool {
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
