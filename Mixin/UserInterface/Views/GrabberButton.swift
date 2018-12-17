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
        maskLayer.path = UIBezierPath(roundedRect: bounds,
                                      byRoundingCorners: [.topLeft, .topRight],
                                      cornerRadii: cornerRadii).cgPath
    }
    
    private func prepare() {
        clipsToBounds = true
        layer.mask = maskLayer
        chevronView.isUserInteractionEnabled = false
        addSubview(chevronView)
    }
    
}
