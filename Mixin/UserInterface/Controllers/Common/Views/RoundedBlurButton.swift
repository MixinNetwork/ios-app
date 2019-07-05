import UIKit

final class RoundedBlurButton: UIButton {
    
    private let blurView = UIVisualEffectView(effect: .lightBlur)
    
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
        let length = min(bounds.width, bounds.height)
        blurView.frame.size = CGSize(width: length, height: length)
        blurView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        blurView.layer.cornerRadius = bounds.height / 2
        sendSubviewToBack(blurView)
    }
    
    private func prepare() {
        blurView.isUserInteractionEnabled = false
        blurView.clipsToBounds = true
        insertSubview(blurView, at: 0)
    }
    
}
