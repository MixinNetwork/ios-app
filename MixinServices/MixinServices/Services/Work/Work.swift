import Foundation

protocol WorkStateMonitor: AnyObject {
    func work(_ work: Work, stateDidChangeTo newState: Work.State)
}

open class Work {
    
    public let id: String
    
    private let lock = NSRecursiveLock()
    
    private var _state: State
    
    private weak var stateMonitor: WorkStateMonitor?
    
    public init(id: String, state: State) {
        self.id = id
        self._state = state
    }
    
    func setStateMonitor(_ monitor: WorkStateMonitor) -> Bool {
        lock.lock()
        defer {
            lock.unlock()
        }
        if stateMonitor == nil {
            stateMonitor = monitor
            return true
        } else {
            return false
        }
    }
    
    // Override this if you want precisely control of state
    open func start() {
        state = .executing
        do {
            try main()
            state = .finished(.success)
        } catch {
            state = .finished(.failed(error))
        }
    }
    
    // Override this for straight synchronous works
    open func main() throws {
        
    }
    
    open func cancel() {
        state = .finished(.cancelled)
    }
    
}

// MARK: - Equatable
extension Work: Equatable {
    
    public static func == (lhs: Work, rhs: Work) -> Bool {
        lhs.id == rhs.id
    }
    
}

// MARK: - Hashable
extension Work: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
}

// MARK: - CustomStringConvertible
extension Work: CustomStringConvertible {
    
    open var description: String {
        id
    }
    
}

// MARK: - States
extension Work {
    
    public enum State {
        
        public enum Result {
            case success
            case failed(Error)
            case cancelled
        }
        
        case preparing
        case ready
        case executing
        case finished(Result)
        
    }
    
    public var state: State {
        set {
            lock.lock()
            switch (_state, newValue) {
            case (.preparing, .ready), (.ready, .executing), (.ready, .finished), (.executing, .finished):
                _state = newValue
                stateMonitor?.work(self, stateDidChangeTo: newValue)
            default:
                assertionFailure("Work's state shouldn't be set to \(newValue) from \(_state)")
            }
            lock.unlock()
        }
        get {
            lock.lock()
            let state = _state
            lock.unlock()
            return _state
        }
    }
    
    public var isReady: Bool {
        if case .ready = state {
            return true
        } else {
            return false
        }
    }
    
    public var isExecuting: Bool {
        if case .executing = state {
            return true
        } else {
            return false
        }
    }
    
    public var isFinished: Bool {
        if case .finished = state {
            return true
        } else {
            return false
        }
    }
    
}
