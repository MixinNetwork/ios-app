import Foundation
import MixinServices

final class NetworkSpeedInspector {
    
    private let formatter = ByteCountFormatter()
    
    private var count: Int64 = 0
    
    private weak var timer: Timer?
    
    deinit {
        stopAutoConsuming()
    }
    
    func clear() {
        assert(Queue.main.isCurrent)
        count = 0
    }
    
    func store(byteCount: Int) {
        assert(Queue.main.isCurrent)
        self.count += Int64(byteCount)
    }
    
}

// - MARK: Manual Consuming
extension NetworkSpeedInspector {
    
    func consume(timeUnit: String = "s") -> String {
        assert(Queue.main.isCurrent)
        let count = self.count
        self.count = 0
        let string = formatter.string(fromByteCount: count)
        return string + "/" + timeUnit
    }
    
}

// - MARK: Auto Consuming
extension NetworkSpeedInspector {
    
    func scheduleAutoConsuming(_ block: @escaping (String) -> Void) {
        assert(Queue.main.isCurrent)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [unowned self] _ in
            let count = self.consume()
            block(count)
        }
    }
    
    func stopAutoConsuming() {
        assert(Queue.main.isCurrent)
        timer?.invalidate()
    }
    
}
