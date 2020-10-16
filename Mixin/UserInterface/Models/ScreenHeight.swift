import UIKit

enum ScreenHeight {
    
    /*
     Short
     iPhone 4”:                         320 x 568 pt
     
     Medium
     iPhone 4.7”:                       375 x 667 pt
     iPhone 5.4” & 5.8” (Zoom mode):    320 x 693 pt
     
     Long
     iPhone 5.5”:                       414 x 736 pt
     iPhone 5.4” & 5.8”:                375 x 812 pt
     
     Extra Long
     iPhone 6.1" (2020):                390 x 844 pt
     iPhone 6.1” (2018–2019) & 6.5”:    414 x 896 pt
     iPhone 6.7”:                       428 x 926 pt
    */
    
    case short
    case medium
    case long
    case extraLong
    
    static let current: ScreenHeight = {
        let height = max(UIScreen.main.bounds.height, UIScreen.main.bounds.width)
        if height <= (568 + 667) / 2 {
            return .short
        } else if height <= (693 + 736) / 2 {
            return .medium
        } else if height <= (812 + 844) / 2 {
            return .long
        } else {
            return .extraLong
        }
    }()
    
}
