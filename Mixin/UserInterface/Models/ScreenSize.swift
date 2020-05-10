import UIKit

enum ScreenSize: Int {
    
    case inch3_5 = 35
    case inch4 = 40
    case inch4_7 = 47
    case inch5_5 = 55
    case inch5_8 = 58
    case inch6_1 = 61
    case inch6_5 = 65
    case unknown = 0
    
    static let current: ScreenSize = {
        let screenHeight = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        switch screenHeight {
        case 480:
            return .inch3_5
        case 568:
            return .inch4
        case 667:
            return .inch4_7
        case 736:
            return .inch5_5
        case 812:
            return .inch5_8
        case 896:
            return UIScreen.main.scale == 3 ? .inch6_5 : .inch6_1
        default:
            return .unknown
        }
    }()
    
}

extension ScreenSize: Comparable {
    
    static func <(lhs: ScreenSize, rhs: ScreenSize) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    static func <=(lhs: ScreenSize, rhs: ScreenSize) -> Bool {
        lhs.rawValue <= rhs.rawValue
    }
    
    static func >=(lhs: ScreenSize, rhs: ScreenSize) -> Bool {
        lhs.rawValue >= rhs.rawValue
    }
    
    static func >(lhs: ScreenSize, rhs: ScreenSize) -> Bool {
        lhs.rawValue > rhs.rawValue
    }
    
}
