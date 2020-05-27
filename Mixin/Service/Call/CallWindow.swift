import UIKit

class CallWindow: UIWindow {
    
    init(frame: CGRect, root: UIViewController) {
        super.init(frame: frame)
        self.rootViewController = root
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
}
