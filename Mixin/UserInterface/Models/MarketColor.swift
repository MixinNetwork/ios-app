import UIKit
import MixinServices

enum MarketColor {
    
    case rising
    case falling
    case arbitrary(UIColor)
    
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
        case .arbitrary(let color):
            color
        }
    }
    
    static func byValue(_ decimal: Decimal) -> MarketColor {
        decimal >= 0 ? .rising : .falling
    }
    
}
