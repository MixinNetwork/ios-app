import Foundation

public class WorkManager {
    
    public static let general = WorkManager(label: "General", maxConcurrentWorkCount: 6)
    
    let maxConcurrentWorkCount: Int
    let label: StaticString
    
    private let lock = NSRecursiveLock()
    private let dispatchQueue: DispatchQueue
    
    private var executingWorks: Set<Work> = []
    private var pendingWorks: [Work] = []
    
    var works: [Work] {
        lock.lock()
        var works = Array(executingWorks)
        works.append(contentsOf: pendingWorks)
        lock.unlock()
        return works
    }
    
    init(label: StaticString, maxConcurrentWorkCount: Int) {
        self.label = label
        self.maxConcurrentWorkCount = maxConcurrentWorkCount
        let attributes: DispatchQueue.Attributes = maxConcurrentWorkCount == 1 ? [] : .concurrent
        dispatchQueue = DispatchQueue(label: "one.mixin.services.WorkManager.\(label)", attributes: attributes)
    }
    
    public func wakeUpPersistedWorks(with types: [PersistableWork.Type], completion: ((WorkManager) -> Void)? = nil) {
        dispatchQueue.async {
            let keyPairs = types.map { type in
                (type.typeIdentifier, type)
            }
            let types = [String: PersistableWork.Type](uniqueKeysWithValues: keyPairs)
            let identifiers = [String](types.keys)
            for persisted in WorkDAO.shared.works(with: identifiers) {
                guard let Work = types[persisted.type] else {
                    continue
                }
                do {
                    let work = try Work.init(id: persisted.id, context: persisted.context)
                    self.addWork(work, persistIfAvailable: false)
                } catch {
                    Logger.general.error(category: "WorkManager", message: "[\(self.label)] Failed to init \(persisted)")
                }
            }
            completion?(self)
        }
    }
    
    public func addWork(_ work: Work) {
        addWork(work, persistIfAvailable: true)
    }
    
    public func cancelAllWorks() {
        Logger.general.debug(category: "WorkManager", message: "[\(label)] Will cancel all works")
        works.forEach { $0.cancel() }
    }
    
    public func cancelWork(with id: String) {
        guard let work = works.first(where: { $0.id == id }) else {
            Logger.general.debug(category: "WorkManager", message: "[\(label)] Cancel \(id) but finds nothing")
            return
        }
        Logger.general.debug(category: "WorkManager", message: "[\(label)] Cancel \(id)")
        work.cancel()
    }
    
    private func addWork(_ work: Work, persistIfAvailable: Bool) {
        guard work.setStateMonitor(self) else {
            assertionFailure("Adding work to multiple manager is not supported")
            return
        }
        lock.lock()
        defer {
            lock.unlock()
        }
        let isAlreadyScheduled = executingWorks.contains(work) || pendingWorks.contains(work)
        guard !isAlreadyScheduled else {
            Logger.general.warn(category: "WorkManager", message: "[\(label)] Add a duplicated work: \(work)")
            return
        }
        if persistIfAvailable, let work = work as? PersistableWork {
            let persisted = PersistedWork(id: work.id,
                                          type: type(of: work).typeIdentifier,
                                          context: work.context,
                                          priority: work.priority)
            WorkDAO.shared.save(work: persisted,
                                completion: work.persistenceDidComplete)
        }
        if work.isReady, executingWorks.count < maxConcurrentWorkCount {
            Logger.general.debug(category: "WorkManager", message: "[\(label)] Start \(work) because of adding to queue")
            executingWorks.insert(work)
            dispatchQueue.async(execute: work.start)
        } else {
            Logger.general.debug(category: "WorkManager", message: "[\(label)] Pending \(work)")
            pendingWorks.append(work)
        }
    }
    
}

extension WorkManager: WorkStateMonitor {
    
    func work(_ work: Work, stateDidChangeTo newState: Work.State) {
        switch newState {
        case .preparing:
            assertionFailure("No way a work becomes preparing")
        case .ready:
            lock.lock()
            if executingWorks.count < maxConcurrentWorkCount, let pendingWorksIndex = pendingWorks.firstIndex(of: work) {
                Logger.general.debug(category: "WorkManager", message: "[\(label)] Execute \(work) because of readiness change")
                pendingWorks.remove(at: pendingWorksIndex)
                executingWorks.insert(work)
                lock.unlock()
                dispatchQueue.async(execute: work.start)
            } else {
                lock.unlock()
            }
        case .executing:
            Logger.general.debug(category: "WorkManager", message: "[\(label)] Executing: \(work)")
        case .finished(let result):
            Logger.general.debug(category: "WorkManager", message: "[\(label)] Finished: \(work)")
            if let work = work as? PersistableWork {
                WorkDAO.shared.delete(id: work.id)
            }
            lock.lock()
            pendingWorks.removeAll { pendingWork in
                pendingWork == work
            }
            executingWorks.remove(work)
            if executingWorks.count < maxConcurrentWorkCount, let index = pendingWorks.firstIndex(where: { $0.isReady }) {
                let nextWork = pendingWorks.remove(at: index)
                executingWorks.insert(nextWork)
                lock.unlock()
                Logger.general.debug(category: "WorkManager", message: "[\(label)] Execute \(nextWork) because of another work finished")
                dispatchQueue.async(execute: work.start)
            } else {
                lock.unlock()
            }
        }
    }
    
}
