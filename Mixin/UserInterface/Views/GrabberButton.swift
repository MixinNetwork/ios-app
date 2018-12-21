import UIKit

class GrabberButton: UIButton {
    
    let cornerRadii = CGSize(width: 12, height: 12)
    let maskLayer = CAShapeLayer()
    let chevronView = ChevronView()
    
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
        chevronView.frame = bounds
        // Add 1 pt height to mask or the view will be inconsecutive downwards during animation
        let rect = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height + 1)
        maskLayer.path = UIBezierPath(roundedRect: rect,
                                      byRoundingCorners: [.topLeft, .topRight],
                                      cornerRadii: cornerRadii).cgPath
    }
    
    private func prepare() {
        clipsToBounds = true
        layer.mask = maskLayer
        chevronView.isUserInteractionEnabled = false
        addSubview(chevronView)
        setNeedsLayout()
        layoutIfNeeded()
    }
    
}
