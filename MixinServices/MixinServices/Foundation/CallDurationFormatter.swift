import Foundation

public enum CallDurationFormatter {
    
    private static let lessThanHourFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        formatter.unitsStyle = .positional
        return formatter
    }()
    
    private static let largerThanHourFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second, .hour]
        formatter.zeroFormattingBehavior = .pad
        formatter.unitsStyle = .positional
        return formatter
    }()
    
    public static func string(from duration: TimeInterval) -> String? {
        let formatter: DateComponentsFormatter
        if duration / 60 / 60 > 1 {
            return largerThanHourFormatter.string(from: duration)
        } else {
            return lessThanHourFormatter.string(from: duration)
        }
    }
    
}
