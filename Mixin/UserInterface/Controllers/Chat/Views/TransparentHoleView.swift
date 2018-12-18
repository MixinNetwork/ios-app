import UIKit

class TransparentHoleView: UIView {
    
    @IBInspectable var radius: CGFloat = 37
    
    override class var layerClass: AnyClass {
        return CAShapeLayer.self
    }
    
    override var layer: CAShapeLayer {
        return super.layer as! CAShapeLayer
    }
    
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
        let holeRect = CGRect(x: bounds.width / 2 - radius,
                              y: bounds.height / 2 - radius,
                              width: radius * 2,
                              height: radius * 2)
        let holePath = UIBezierPath(roundedRect: holeRect, cornerRadius: radius)
        let path = UIBezierPath(rect: bounds)
        path.usesEvenOddFillRule = true
        path.append(holePath)
        layer.path = path.cgPath
    }
    
    private func prepare() {
        backgroundColor = .clear
        layer.fillRule = .evenOdd
        layer.fillColor = UIColor.white.cgColor
    }
    
}
