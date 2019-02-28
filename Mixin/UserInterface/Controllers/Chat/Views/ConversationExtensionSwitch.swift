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
                self.updateAppearance()
            }
        }
    }
    
    private let iconLayer = CAShapeLayer()
    private let offColor = UIColor(rgbValue: 0x3A3C3E).cgColor
    private let onColor = UIColor(rgbValue: 0x397EE4).cgColor
    private let animationDuration: TimeInterval = 0.2
    
    private var _isOn = false
    
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
        isUserInteractionEnabled = false
        _isOn.toggle()
        sendActions(for: .valueChanged)
        UIView.animate(withDuration: animationDuration, animations: {
            self.updateAppearance()
        }, completion: { (finished) in
            self.isUserInteractionEnabled = true
        })
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        iconLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
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
    }
    
    private func updateAppearance() {
        if _isOn {
            transform = CGAffineTransform(rotationAngle: .pi / 4)
            iconLayer.fillColor = onColor
        } else {
            transform = .identity
            iconLayer.fillColor = offColor
        }
    }
    
}
