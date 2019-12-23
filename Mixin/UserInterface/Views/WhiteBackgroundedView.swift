import UIKit

class WhiteBackgroundedView: UIView {
    
    override var backgroundColor: UIColor? {
        get {
            return .background
        }
        set {
            
        }
    }
    
    convenience init() {
        self.init(frame: .zero)
        super.backgroundColor = .background
    }
    
}
