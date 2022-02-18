import UIKit

class GalleryView: UIView {
    
    weak var scrollView: UIScrollView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func orientationDidChanged() {
        scrollView?.isScrollEnabled = UIWindow.isPortrait
    }
    
}
