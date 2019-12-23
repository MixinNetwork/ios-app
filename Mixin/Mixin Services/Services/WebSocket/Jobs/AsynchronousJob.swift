import Foundation

open class AsynchronousJob: BaseJob {
    
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
    
    override open var isFinished: Bool {
        return isFinishedStatus
    }
    
    override open var isExecuting: Bool {
        return isExecutingStatus
    }
    
    override open var isAsynchronous: Bool {
        return true
    }
    
    override open func start() {
        guard !isCancelled, LoginManager.shared.isLoggedIn else {
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
