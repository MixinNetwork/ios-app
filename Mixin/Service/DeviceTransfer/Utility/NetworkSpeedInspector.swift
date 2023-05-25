import Foundation
import MixinServices

final class NetworkSpeedInspector {
    
    private let formatter = ByteCountFormatter()
    
    private var byteCount: Int64 = 0
    
    private weak var timer: Timer?
    
    deinit {
        invalidateAutoReporting()
    }
    
    func clear() {
        assert(Queue.main.isCurrent)
        byteCount = 0
    }
    
    func add(byteCount: Int) {
        assert(Queue.main.isCurrent)
        self.byteCount += Int64(byteCount)
    }
    
}

// - MARK: Manual Reporting
extension NetworkSpeedInspector {
    
    func drain(timeUnit: String = "s") -> String {
        assert(Queue.main.isCurrent)
        let count = self.byteCount
        self.byteCount = 0
        let string = formatter.string(fromByteCount: count)
        return string + "/" + timeUnit
    }
    
}

// - MARK: Auto Reporting
extension NetworkSpeedInspector {
    
    func scheduleAutoReporting(_ report: @escaping (String) -> Void) {
        assert(Queue.main.isCurrent)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            if let speed = self?.drain() {
                report(speed)
            } else {
                Logger.general.warn(category: "NetworkSpeedInspector", message: "Timer fired after deinited")
            }
        }
    }
    
    func invalidateAutoReporting() {
        assert(Queue.main.isCurrent)
        timer?.invalidate()
    }
    
}
