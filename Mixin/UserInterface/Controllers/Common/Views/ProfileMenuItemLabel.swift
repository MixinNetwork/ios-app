import UIKit

class ProfileMenuItemLabel: UILabel {
    
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
