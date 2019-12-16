import Foundation

class AsynchronousJob: BaseJob {

    private var isExecutingStatus: Bool = false {
        willSet {
            willChangeValue(forKey: "isExecuting")
        }
        didSet {
            didChangeValue(forKey: "isExecuting")
        }
    }

    private var isFinishedStatus: Bool = false {
        willSet {
            willChangeValue(forKey: "isFinished")
        }
        didSet {
            didChangeValue(forKey: "isFinished")
        }
    }

    override var isFinished: Bool {
        return isFinishedStatus
    }

    override var isExecuting: Bool {
        return isExecutingStatus
    }

    override var isAsynchronous: Bool {
        return true
    }

    override func start() {
        guard !isCancelled, AccountAPI.shared.didLogin else {
            finishJob()
            return
        }
        isExecutingStatus = true
        if !execute() {
            finishJob()
        }
    }

    func execute() -> Bool {
        fatalError("Subclasses must implement `execute`.")
    }

    func finishJob() {
        isFinishedStatus = true
    }
}
