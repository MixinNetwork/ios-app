import UIKit

class ConversationExtensionSwitch: UIControl {
    
    var isOn: Bool {
        get {
            return _isOn
        }
        set {
            guard _isOn != newValue else {
                return
            }
            _isOn = newValue
            UIView.animate(withDuration: animationDuration) {
                self.updateIconLayer()
            }
        }
    }
    
    private let iconLayer = CAShapeLayer()
    private let animationDuration: TimeInterval = 0.2
    
    private var _isOn = false
    
    private var onColor: CGColor {
        R.color.theme()!.cgColor
    }
    
    private var offColor: CGColor {
        R.color.icon_fill()!.cgColor
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        prepare()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        UIView.animate(withDuration: animationDuration, animations: {
            self.transform = self.transform.scaledBy(x: 0.8, y: 0.8)
        })
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(withDuration: animationDuration, animations: {
            self.transform = .identity
        })
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: animationDuration, animations: {
            self.transform = .identity
        })
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        iconLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateIconLayer()
    }
    
    @objc func tapAction(_ sender: UITapGestureRecognizer) {
        isUserInteractionEnabled = false
        _isOn.toggle()
        sendActions(for: .valueChanged)
        UIView.animate(withDuration: animationDuration, animations: {
            self.updateIconLayer()
        }, completion: { (finished) in
            self.isUserInteractionEnabled = true
        })
    }
    
    private func prepare() {
        iconLayer.bounds = CGRect(x: 0, y: 0, width: 26, height: 26)
        let verticalLineRect = CGRect(x: 12, y: 4, width: 2, height: 18)
        let path = UIBezierPath(roundedRect: verticalLineRect, cornerRadius: 1)
        let horizontalLineRect = CGRect(x: 4, y: 12, width: 18, height: 2)
        path.append(UIBezierPath(roundedRect: horizontalLineRect, cornerRadius: 1))
        iconLayer.path = path.cgPath
        iconLayer.fillColor = offColor
        iconLayer.lineCap = .round
        layer.addSublayer(iconLayer)
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        addGestureRecognizer(recognizer)
    }
    
    private func updateIconLayer() {
        if _isOn {
            iconLayer.transform = CATransform3DMakeRotation(.pi / 4, 0, 0, 1)
            iconLayer.fillColor = onColor
        } else {
            iconLayer.transform = CATransform3DIdentity
            iconLayer.fillColor = offColor
        }
    }
    
}
