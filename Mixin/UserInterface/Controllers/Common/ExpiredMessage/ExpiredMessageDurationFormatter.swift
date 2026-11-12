import Foundation
import MixinServices

enum ExpiredMessageDurationFormatter {
    
    static func string(from value: Int64) -> String {
        guard value > 0 else {
            return R.string.localizable.off()
        }
        let units: [(Int64, String, String)] = [
            (Int64(365 * TimeInterval.day), R.string.localizable.unit_year(), R.string.localizable.unit_year_count()),
            (Int64(TimeInterval.month), R.string.localizable.unit_month(), R.string.localizable.unit_month_count()),
            (Int64(TimeInterval.week), R.string.localizable.unit_week(), R.string.localizable.unit_week_count()),
            (Int64(TimeInterval.day), R.string.localizable.unit_day(), R.string.localizable.unit_day_count()),
            (Int64(TimeInterval.hour), R.string.localizable.unit_hour(), R.string.localizable.unit_hour_count()),
            (Int64(TimeInterval.minute), R.string.localizable.unit_minute(), R.string.localizable.unit_minute_count()),
            (1, R.string.localizable.unit_second(), R.string.localizable.unit_second_count()),
        ]
        for (interval, singular, plural) in units where value % interval == 0 {
            let count = value / interval
            return "\(count) \(count == 1 ? singular : plural)"
        }
        return R.string.localizable.off()
    }
    
}
