import UIKit

class WhiteBackgroundedView: UIView {
    
    override var backgroundColor: UIColor? {
        get {
            return .white
        }
        set {
            
        }
    }
    
    convenience init() {
        self.init(frame: .zero)
        super.backgroundColor = .white
    }
    
}
