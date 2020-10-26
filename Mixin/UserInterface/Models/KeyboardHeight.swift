import CoreGraphics

struct KeyboardHeight {
    
    /*
     non-Notched
     iPhone 4”:                         320 x 568 pt Keyboard: 254
     iPhone 4.7”:                       375 x 667 pt Keyboard: 260
     iPhone 5.5”:                       414 x 736 pt Keyboard: 271
     
     Notched
     iPhone 5.4” & 5.8” (Zoom mode):    320 x 693 pt Keyboard: 319
     iPhone 5.4” & 5.8”:                375 x 812 pt Keyboard: 336
     iPhone 6.1" (2020):                390 x 844 pt Keyboard: 336
     iPhone 6.1” (2018–2019) & 6.5”:    414 x 896 pt Keyboard: 346
     iPhone 6.7”:                       428 x 926 pt Keyboard: 346
     */
    
    static let `default`: CGFloat = {
        if AppDelegate.current.mainWindow.safeAreaInsets.bottom > 1 {
            if ScreenHeight.current <= .medium {
                return 319
            } else if ScreenHeight.current <= .long {
                return 336
            } else {
                return 346
            }
        } else {
            if ScreenHeight.current <= .short {
                return 254
            } else if ScreenHeight.current <= .medium {
                return 260
            } else {
                return 271
            }
        }
    }()
    
    static let minReasonable = `default` - 44
    static let maxReasonable = `default` + 44
    
    static var last = `default`
    
}
