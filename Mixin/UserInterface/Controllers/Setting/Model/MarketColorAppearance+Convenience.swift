import Foundation
import MixinServices

extension MarketColorAppearance {
    
    var description: String {
        switch self {
        case .greenUpRedDown:
            R.string.localizable.green_up_red_down()
        case .redUpGreenDown:
            R.string.localizable.red_up_green_down()
        }
    }
    
    var image: UIImage {
        switch self {
        case .greenUpRedDown:
            R.image.green_up()!
        case .redUpGreenDown:
            R.image.red_up()!
        }
    }
    
}
