import Foundation
import MixinServices

final class NetworkSpeedConditioner {
    
    private let maxCount: Int
    private let timeoutInterval: TimeInterval
    private let semaphore = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    
    private var enqueuedCount = 0
    private var pendingCount: Int?
    
    init(maxCount: Int, timeoutInterval: TimeInterval) {
        self.maxCount = maxCount
        self.timeoutInterval = timeoutInterval
    }
    
    func wait(_ count: Int) -> DispatchTimeoutResult {
        lock.lock()
        let newDataCount = enqueuedCount + count
        if newDataCount > maxCount {
            pendingCount = count
            lock.unlock()
            let result = semaphore.wait(timeout: .now() + timeoutInterval)
            lock.lock()
            enqueuedCount += count
            pendingCount = nil
            lock.unlock()
            return result
        } else {
            enqueuedCount = newDataCount
            lock.unlock()
            return .success
        }
    }
    
    func signal(_ count: Int) {
        lock.lock()
        enqueuedCount -= count
        if let pendingCount, enqueuedCount + pendingCount <= maxCount || enqueuedCount == 0 {
            semaphore.signal()
        }
        lock.unlock()
    }
    
}
