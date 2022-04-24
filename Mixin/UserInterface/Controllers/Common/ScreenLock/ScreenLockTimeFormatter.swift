import Foundation
import MixinServices

enum ScreenLockTimeFormatter {
    
    static func string(from timeInterval: TimeInterval) -> String {
        if timeInterval == 0 {
            return R.string.localizable.immediately()
        } else if timeInterval == 60 * 60 {
            return R.string.localizable.one_hour()
        } else if timeInterval == 60 {
            return R.string.localizable.minute(1)
        } else {
            return R.string.localizable.minute_count(Int(timeInterval / 60))
        }
    }
    
}
