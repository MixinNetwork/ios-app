import UIKit

class ProfileMenuItemLabel: UILabel {
    
    // On iOS 12 and below, UIView's property get reset with values in Interface Builder
    // Looks like a bug already fixed in iOS 13
    // See also https://procrastinative.ninja/2018/07/16/debugging-ios-named-colors/
    override var textColor: UIColor! {
        get {
            super.textColor
        }
        set {
            guard ibOverridingTextColor == nil || ibOverridingTextColor == newValue else {
                return
            }
            super.textColor = newValue
        }
    }
    
    var ibOverridingTextColor: UIColor? {
        didSet {
            super.textColor = ibOverridingTextColor
        }
    }
    
}
