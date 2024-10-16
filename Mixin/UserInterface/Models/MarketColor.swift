import UIKit
import MixinServices

enum MarketColor: Codable {
    
    case rising
    case falling
    
    var uiColor: UIColor {
        switch self {
        case .rising:
            switch AppGroupUserDefaults.User.marketColorAppearance {
            case .greenUpRedDown:
                R.color.market_green()!
            case .redUpGreenDown:
                R.color.market_red()!
            }
        case .falling:
            switch AppGroupUserDefaults.User.marketColorAppearance {
            case .greenUpRedDown:
                R.color.market_red()!
            case .redUpGreenDown:
                R.color.market_green()!
            }
        }
    }
    
    static func byValue(_ decimal: Decimal) -> MarketColor {
        decimal >= 0 ? .rising : .falling
    }
    
}
