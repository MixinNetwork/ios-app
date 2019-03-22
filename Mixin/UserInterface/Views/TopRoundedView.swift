import UIKit

class TopRoundedView: UIView {
    
    let cornerRadii = CGSize(width: 13, height: 13)
    let topRoundedMaskLayer = CAShapeLayer()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(roundedRect: bounds,
                                byRoundingCorners: [.topLeft, .topRight],
                                cornerRadii: cornerRadii)
        topRoundedMaskLayer.path = path.cgPath
        layer.mask = topRoundedMaskLayer
    }
    
}
