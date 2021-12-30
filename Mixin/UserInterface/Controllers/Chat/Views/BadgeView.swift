import UIKit

protocol BadgeViewDelegate: AnyObject {
    func didTapBadgeView(_ badgeView: BadgeView)
}

class BadgeView: UILabel {
    
    weak var delegate: BadgeViewDelegate?
    
    var badgeColor: UIColor = .clear {
        didSet {
            setNeedsDisplay()
        }
    }
    var borderWidth: CGFloat = 0 {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }
    var borderColor: UIColor = .clear {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }
    var cornerRadius: CGFloat = 0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        textAlignment = NSTextAlignment.center
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tapGesture)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        let rectInset = rect.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
        var path: UIBezierPath?
        if cornerRadius > 0 {
            path = UIBezierPath(roundedRect: rectInset, cornerRadius: cornerRadius)
        } else {
            path = UIBezierPath(rect: rectInset)
        }
        badgeColor.setFill()
        path?.fill()
        if borderWidth > 0 {
            borderColor.setStroke()
            path?.lineWidth = borderWidth
            path?.stroke()
        }
        super.draw(rect)
    }
    
    @objc private func didTap() {
        delegate?.didTapBadgeView(self)
    }
  
}
