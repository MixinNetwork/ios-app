import UIKit

class SolidBackgroundColoredView: UIView {
    
    override var backgroundColor: UIColor? {
        get {
            backgroundColorIgnoringSystemSettings
        }
        set {
            
        }
    }
    
    var backgroundColorIgnoringSystemSettings: UIColor = .clear {
        didSet {
            super.backgroundColor = backgroundColorIgnoringSystemSettings
        }
    }
    
}
