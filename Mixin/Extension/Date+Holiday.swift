import Foundation
import MixinServices

extension Date {
    
    var isChristmas: Bool {
        let thisYear = Calendar.gregorian.component(.year, from: self)
        guard let base = DateComponents(calendar: .gregorian, timeZone: .current, year: thisYear, month: 12, day: 25).date else {
            return false
        }
        let start = base.addingTimeInterval(-secondsPerDay).timeIntervalSince1970
        let end = base.addingTimeInterval(secondsPerDay).timeIntervalSince1970
        return (start...end).contains(self.timeIntervalSince1970)
    }
    
    var isChineseNewYear: Bool {
        let thisYear = Calendar.chinese.component(.year, from: self)
        switch Calendar.chinese.component(.month, from: self) {
        case 1:
            guard let base = DateComponents(calendar: .chinese, timeZone: .current, year: thisYear, month: 1, day: 1).date else {
                return false
            }
            let start = base.timeIntervalSince1970
            let end = base.timeIntervalSince1970 + 6 * secondsPerDay
            return (start...end).contains(self.timeIntervalSince1970)
        case 12:
            guard let base = DateComponents(calendar: .chinese, timeZone: .current, year: thisYear + 1, month: 1, day: 1).date else {
                return false
            }
            let start = base.timeIntervalSince1970 - secondsPerDay
            let end = base.timeIntervalSince1970
            return (start...end).contains(self.timeIntervalSince1970)
        default:
            return false
        }
    }
    
}
