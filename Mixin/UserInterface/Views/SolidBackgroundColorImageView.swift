import UIKit

class SolidBackgroundColorImageView: UIImageView {
    
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
