import UIKit

final class GalleryTransitionOverlayView: UIView {
    
    let backgroundView = UIView()
    
    init(frame: CGRect, backgroundAlpha: CGFloat) {
        super.init(frame: frame)
        backgroundColor = .clear
        backgroundView.backgroundColor = .black
        backgroundView.alpha = backgroundAlpha
        backgroundView.frame = bounds
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(backgroundView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
