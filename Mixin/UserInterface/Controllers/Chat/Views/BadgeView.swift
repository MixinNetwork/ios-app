import UIKit

class BadgeView: UILabel {
    
    var badgeColor: UIColor = .clear {
        didSet {
            setNeedsDisplay()
        }
    }
    var borderWidth: CGFloat = 0 {
        didSet {
            setNeedsDisplay()
        }
    }
    var borderColor: UIColor = .clear {
        didSet {
            setNeedsDisplay()
        }
    }
    var cornerRadius: CGFloat = 0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override func draw(_ rect: CGRect) {
        let rectInset = rect.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
        let path: UIBezierPath
        if cornerRadius > 0 {
            path = UIBezierPath(roundedRect: rectInset, cornerRadius: cornerRadius)
        } else {
            path = UIBezierPath(rect: rectInset)
        }
        badgeColor.setFill()
        path.fill()
        if borderWidth > 0 {
            borderColor.setStroke()
            path.lineWidth = borderWidth
            path.stroke()
        }
        super.draw(rect)
    }
    
    private func  prepare() {
        textAlignment = NSTextAlignment.center
    }
    
}
