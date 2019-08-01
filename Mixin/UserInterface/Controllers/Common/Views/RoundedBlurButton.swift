import UIKit

final class RoundedBlurButton: UIButton {
    
    private let blurView = UIVisualEffectView(effect: .darkBlur)
    
    var backgroundSize: CGSize?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let blurViewSize: CGSize
        if let size = backgroundSize {
            blurViewSize = size
        } else {
            let length = min(bounds.width, bounds.height)
            blurViewSize = CGSize(width: length, height: length)
        }
        blurView.bounds.size = blurViewSize
        blurView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        blurView.layer.cornerRadius = blurViewSize.width / 2
        sendSubviewToBack(blurView)
    }
    
    private func prepare() {
        blurView.isUserInteractionEnabled = false
        blurView.clipsToBounds = true
        insertSubview(blurView, at: 0)
    }
    
}
