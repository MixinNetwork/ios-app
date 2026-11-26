import Foundation

enum PerpetualTimeFrame: String, CaseIterable {
    case oneMinute = "1m"
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    case oneHour = "1h"
    case fourHours = "4h"
    case oneDay = "1d"
    case oneWeek = "1w"
    
    var durationMillis: Int64 {
        switch self {
        case .oneMinute:
            60_000
        case .fiveMinutes:
            300_000
        case .fifteenMinutes:
            900_000
        case .oneHour:
            3_600_000
        case .fourHours:
            14_400_000
        case .oneDay:
            86_400_000
        case .oneWeek:
            604_800_000
        }
    }
    
    var usesDateOnlyFormat: Bool {
        switch self {
        case .oneMinute, .fiveMinutes, .fifteenMinutes, .oneHour, .fourHours:
            false
        case .oneDay, .oneWeek:
            true
        }
    }
}
