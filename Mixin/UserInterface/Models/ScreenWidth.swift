import UIKit

enum ScreenWidth: Int {
    
    /*
     Short
     iPhone 4”:                         320 x 568 pt
     iPhone 5.4” & 5.8” (Zoom mode):    320 x 693 pt

     Medium
     iPhone 4.7”:                       375 x 667 pt
     iPhone 5.4” & 5.8”:                375 x 812 pt
     iPhone 6.1" (2020):                390 x 844 pt

     Long
     iPhone 5.5”:                       414 x 736 pt
     iPhone 6.1” (2018–2019) & 6.5”:    414 x 896 pt
     iPhone 6.7”:                       428 x 926 pt
    */
    
    case short = 0
    case medium
    case long
    
    static let current: ScreenWidth = {
        let height = min(UIScreen.main.bounds.height, UIScreen.main.bounds.width)
        if height <= 375 {
            return .short
        } else if height <= 390 {
            return .medium
        } else {
            return .long
        }
    }()
    
}

extension ScreenWidth: Comparable {
    
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    static func <= (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue <= rhs.rawValue
    }
    
    static func >= (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue >= rhs.rawValue
    }
    
    static func > (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue > rhs.rawValue
    }
    
}
