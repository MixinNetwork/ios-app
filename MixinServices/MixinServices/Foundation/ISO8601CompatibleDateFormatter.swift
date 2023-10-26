import Foundation

public enum ISO8601CompatibleDateFormatter {
    
    private static let noSubsecondFormatter = ISO8601DateFormatter()
    
    private static let subsecond1Formatter: DateFormatter = {
        let formatter = DateFormatter(dateFormat: "yyyy-MM-dd'T'HH:mm:ss.SZZZZZ")
        formatter.locale = .enUSPOSIX
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private static let subsecond10Formatter: DateFormatter = {
        let formatter = DateFormatter(dateFormat: "yyyy-MM-dd'T'HH:mm:ss.SSZZZZZ")
        formatter.locale = .enUSPOSIX
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    public static func string(from date: Date) -> String {
        DateFormatter.iso8601Full.string(from: date)
    }
    
    public static func date(from string: String) -> Date? {
        switch string.count {
        case 20:
            return noSubsecondFormatter.date(from: string)
        case 22:
            return subsecond1Formatter.date(from: string)
        case 23:
            return subsecond10Formatter.date(from: string)
        default:
            return DateFormatter.iso8601Full.date(from: string)
        }
    }
    
}
