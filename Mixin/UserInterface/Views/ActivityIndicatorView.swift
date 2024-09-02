import UIKit

class ActivityIndicatorView: UIView {
    
    enum Style {
        case large
        case medium
        case custom(diameter: CGFloat, lineWidth: CGFloat)
    }
    
    @IBInspectable var hidesWhenStopped: Bool = true {
        didSet {
            if hidesWhenStopped && !_isAnimating {
                isHidden = true
            }
        }
    }
    
    @IBInspectable var isAnimating: Bool {
        get {
            return _isAnimating
        }
        set(wantsAnimation) {
            if wantsAnimation {
                startAnimating()
            } else {
                stopAnimating()
            }
        }
    }
    
    var style: Style = .medium {
        didSet {
            if indicatorLayer != nil {
                reloadIndicatorLayer()
                if _isAnimating {
                    setupAnimation()
                }
            }
        }
    }
    
    var lineWidth: CGFloat {
        switch style {
        case .large:
            3
        case .medium:
            2
        case let .custom(_, lineWidth):
            lineWidth
        }
    }
    
    var contentLength: CGFloat {
        switch style {
        case .large:
            37
        case .medium:
            20
        case let .custom(diameter, _):
            diameter
        }
    }
    
    // Indicator will stay in center vertically if indicatorCenterY is nil
    var indicatorCenterY: CGFloat?
    
    private var indicatorLayer: CAShapeLayer?
    private var _isAnimating = false
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: contentLength, height: contentLength)
    }
    
    override var tintColor: UIColor! {
        didSet {
            indicatorLayer?.strokeColor = tintColor.cgColor
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        registerForNotifications()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        registerForNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let y = indicatorCenterY {
            indicatorLayer?.position = CGPoint(x: bounds.midX, y: y)
        } else {
            indicatorLayer?.position = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }
    
    override func didMoveToWindow() {
        if _isAnimating {
            setupAnimation()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        indicatorLayer?.strokeColor = tintColor.resolvedColor(with: traitCollection).cgColor
    }
    
    func startAnimating() {
        guard !_isAnimating else {
            return
        }
        if indicatorLayer == nil {
            reloadIndicatorLayer()
        }
        if hidesWhenStopped {
            isHidden = false
        }
        setupAnimation()
        _isAnimating = true
    }
    
    func stopAnimating() {
        guard _isAnimating else {
            return
        }
        indicatorLayer?.removeAllAnimations()
        if hidesWhenStopped {
            isHidden = true
        }
        _isAnimating = false
    }
    
    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }
    
    @objc private func applicationDidEnterBackground() {
        indicatorLayer?.removeAllAnimations()
    }
    
    @objc private func applicationWillEnterForeground() {
        if _isAnimating {
            setupAnimation()
        }
    }
    
    private func reloadIndicatorLayer() {
        self.indicatorLayer?.removeFromSuperlayer()
        let indicatorLayer = CAShapeLayer()
        indicatorLayer.backgroundColor = UIColor.clear.cgColor
        indicatorLayer.strokeColor = tintColor.cgColor
        indicatorLayer.fillColor = UIColor.clear.cgColor
        indicatorLayer.lineWidth = lineWidth
        indicatorLayer.lineCap = .round
        indicatorLayer.strokeStart = 0
        indicatorLayer.strokeEnd = 0.8
        indicatorLayer.bounds = CGRect(origin: .zero, size: intrinsicContentSize)
        let length = self.contentLength
        indicatorLayer.path = UIBezierPath(arcCenter: CGPoint(x: length / 2, y: length / 2),
                                           radius: length / 2,
                                           startAngle: 0,
                                           endAngle: .pi * 2,
                                           clockwise: true).cgPath
        layer.addSublayer(indicatorLayer)
        self.indicatorLayer = indicatorLayer
        setNeedsLayout()
    }
    
    private func setupAnimation() {
        guard window != nil, let indicator = indicatorLayer else {
            return
        }
        let anim = CABasicAnimation(keyPath: "transform.rotation.z")
        anim.toValue = CGFloat.pi * 2
        anim.duration = 0.8
        anim.repeatCount = .infinity
        indicator.add(anim, forKey: "rotation")
    }
    
}
