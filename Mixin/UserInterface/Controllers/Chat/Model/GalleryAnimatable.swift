import UIKit

protocol GalleryAnimatable {
    var animationDuration: TimeInterval { get }
    func animate(animations: @escaping () -> Void, completion: (() -> Void)?)
}

extension GalleryAnimatable {
    
    var animationDuration: TimeInterval {
        return 0.3
    }
    
    func animate(animations: @escaping () -> Void, completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: animationDuration, delay: 0, options: .layoutSubviews, animations: animations) { (_) in
            completion?()
        }
    }
    
}
