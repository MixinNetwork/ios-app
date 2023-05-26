import Foundation
import MixinServices

final class NetworkSpeedInspector {
    
    private let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .binary
        formatter.allowsNonnumericFormatting = false
        return formatter
    }()
    
    private var byteCount: Int64 = 0
    
    func clear() {
        assert(Queue.main.isCurrent)
        byteCount = 0
    }
    
    func add(byteCount: Int) {
        assert(Queue.main.isCurrent)
        self.byteCount += Int64(byteCount)
    }
    
    func drain(timeUnit: String = "s") -> String {
        assert(Queue.main.isCurrent)
        let count = self.byteCount
        self.byteCount = 0
        let string = formatter.string(fromByteCount: count)
        return string + "/" + timeUnit
    }
    
}
