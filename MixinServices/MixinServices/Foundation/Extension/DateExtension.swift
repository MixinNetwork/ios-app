import UIKit

public extension Date {
    
    func toUTCString() -> String {
        return DateFormatter.iso8601Full.string(from: self)
    }

    func nanosecond() -> Int64 {
        let nanosecond: Int64 = Int64(Calendar.current.dateComponents([.nanosecond], from: self).nanosecond ?? 0)
        return Int64(self.timeIntervalSince1970 * 1000000000) + nanosecond
    }
    
}

public let mediaDurationFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.minute, .second]
    formatter.zeroFormattingBehavior = [.pad]
    formatter.unitsStyle = .positional
    return formatter
}()
