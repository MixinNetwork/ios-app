import UIKit

class GalleryView: UIView {
    
    weak var scrollView: UIScrollView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        registerForNotification()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForNotification()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitTest = super.hitTest(point, with: event)
        if UIApplication.shared.statusBarOrientation.isPortrait {
            scrollView?.isScrollEnabled = !(hitTest is UISlider)
        }
        return hitTest
    }
    
    @objc func orientationDidChanged() {
        scrollView?.isScrollEnabled = UIDevice.current.orientation.isPortrait
    }
    
    private func registerForNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(orientationDidChanged), name: UIApplication.didChangeStatusBarOrientationNotification, object: nil)
    }
    
}
