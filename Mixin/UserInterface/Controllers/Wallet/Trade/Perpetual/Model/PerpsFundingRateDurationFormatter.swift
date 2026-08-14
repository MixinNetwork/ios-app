import Foundation

enum PerpsFundingRateDurationFormatter {
    
    private static let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second, .hour]
        formatter.zeroFormattingBehavior = .pad
        formatter.unitsStyle = .positional
        return formatter
    }()
    
    static func string(from interval: TimeInterval) -> String? {
        if #available(iOS 16.0, *) {
            Duration.seconds(interval).formatted(
                .time(pattern: .hourMinuteSecond(padHourToLength: 2))
            )
        } else {
            formatter.string(from: interval)
        }
    }
    
}
