import UIKit
import CoreMedia

public extension DateFormatter {

    static let filename = DateFormatter(dateFormat: "yyyy-MM-dd_HH:mm:ss")
    static let log = DateFormatter(dateFormat: "yyyy/MM/dd, hh:mm a")

    convenience init(dateFormat: String) {
        self.init()
        self.dateFormat = dateFormat
        self.locale = Locale.current
        self.timeZone = TimeZone.current
    }

    static let iso8601Full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.locale = .enUSPOSIX
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()

    static let localFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    static let backupFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

public extension Date {

    private static let sourceTimeZone = TimeZone(identifier: "UTC")!
    private static let destinationTimeZone = NSTimeZone.local

    func toUTCString() -> String {
        return DateFormatter.iso8601Full.string(from: self)
    }

    func toLocalDate() -> Date {
        let destinationGMTOffset = Date.destinationTimeZone.secondsFromGMT(for: self)
        let sourceGMTOffset = Date.sourceTimeZone.secondsFromGMT(for: self)
        return Date(timeInterval: TimeInterval(destinationGMTOffset - sourceGMTOffset), since: self)
    }

    func nanosecond() -> Int64 {
        let nanosecond: Int64 = Int64(Calendar.current.dateComponents([.nanosecond], from: self).nanosecond ?? 0)
        return Int64(self.timeIntervalSince1970 * 1000000000) + nanosecond
    }

    func logDatetime() -> String {
        return DateFormatter.log.string(from: self)
    }

    public func within6Hours() -> Date {
        return addingTimeInterval(-21600)
    }

}

public let mediaDurationFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.minute, .second]
    formatter.zeroFormattingBehavior = [.pad]
    formatter.unitsStyle = .positional
    return formatter
}()
