import UIKit

class CallSwitch: UIControl {
    
    var isOn = false {
        didSet {
            updateOpacity(isOn: isOn)
        }
    }
    
    var iconPath: UIBezierPath? {
        didSet {
            updateIcon(path: iconPath)
        }
    }
    
    private let offView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: .darkBlur))
    private let offContentView = UIView()
    private let offIconLayer = CAShapeLayer()
    private let onLayer = CAShapeLayer()
    
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
        offView.layer.cornerRadius = bounds.width / 2
        offContentView.frame = offView.contentView.bounds
        offIconLayer.position = CGPoint(x: offContentView.bounds.midX,
                                        y: offContentView.bounds.midY)
        if let path = iconPath {
            updateOnLayerPath(iconPath: path)
        }
        onLayer.frame = layer.bounds
    }
    
    @objc private func tapAction(_ sender: UITapGestureRecognizer) {
        isOn.toggle()
        sendActions(for: .valueChanged)
    }
    
    private func updateIcon(path: UIBezierPath?) {
        guard let path = path else {
            return
        }
        updateOnLayerPath(iconPath: path)
        offIconLayer.path = path.cgPath
        offIconLayer.bounds.size = path.bounds.size
    }
    
    private func updateOpacity(isOn: Bool) {
        offView.isHidden = isOn
        onLayer.opacity = isOn ? 1 : 0
    }
    
    private func updateOnLayerPath(iconPath: UIBezierPath) {
        let onPath = UIBezierPath(roundedRect: bounds, cornerRadius: bounds.width / 2)
        var transform = CGAffineTransform(translationX: (bounds.width - iconPath.bounds.width) / 2,
                                          y: (bounds.height - iconPath.bounds.height) / 2)
        if let centeredIconPath = iconPath.cgPath.copy(using: &transform) {
            onPath.append(UIBezierPath(cgPath: centeredIconPath))
        }
        onPath.usesEvenOddFillRule = true
        onLayer.path = onPath.cgPath
    }
    
    private func prepare() {
        offIconLayer.backgroundColor = UIColor.clear.cgColor
        offIconLayer.fillColor = UIColor.white.cgColor
        offContentView.layer.addSublayer(offIconLayer)
        
        offContentView.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        offView.contentView.addSubview(offContentView)
        
        offView.clipsToBounds = true
        addSubview(offView)
        offView.snp.makeEdgesEqualToSuperview()
        
        onLayer.fillRule = .evenOdd
        onLayer.fillColor = UIColor.white.cgColor
        layer.addSublayer(onLayer)
        
        updateOpacity(isOn: isOn)
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        addGestureRecognizer(recognizer)
    }
    
}
