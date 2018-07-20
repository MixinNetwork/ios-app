import UIKit

enum ScreenSize {
    
    case inch4
    case inch4_7
    case inch5_5
    case inch5_8
    case unknown
    
    static let current: ScreenSize = {
        let screenHeight = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        switch screenHeight {
        case 568:
            return .inch4
        case 667:
            return .inch4_7
        case 736:
            return .inch5_5
        case 812:
            return .inch5_8
        default:
            return .unknown
        }
    }()
    
}
