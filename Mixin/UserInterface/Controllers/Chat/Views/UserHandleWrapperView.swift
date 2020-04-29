import UIKit

class UserHandleWrapperView: UIView {
    
    var maskHeight: CGFloat {
        get {
            userHandleMaskView.frame.height
        }
        set {
            let frame = CGRect(x: 0,
                               y: bounds.height - newValue,
                               width: bounds.width,
                               height: newValue)
            userHandleMaskView.frame = frame
        }
    }
    
    private lazy var userHandleMaskView = UIView()
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if userHandleMaskView.frame.contains(point) {
            return super.hitTest(point, with: event)
        } else {
            return nil
        }
    }
    
    func addUserHandleView(_ view: UIView) {
        for subview in subviews {
            subview.removeFromSuperview()
        }
        addSubview(view)
        view.snp.makeEdgesEqualToSuperview()
        if mask == nil {
            userHandleMaskView.backgroundColor = .white
            mask = userHandleMaskView
        }
    }
    
}
