import UIKit

class ActivityIndicatorView: UIView {
    
    @IBInspectable var usesLargerStyle: Bool = false {
        didSet {
            if usesLargerStyle != oldValue && (_isAnimating || indicatorLayer != nil) {
                reloadIndicatorLayer(usesLargerStyle: usesLargerStyle)
            }
            if _isAnimating {
                setupAnimation()
            }
        }
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
    
    private var indicatorLayer: CAShapeLayer!
    private var _isAnimating = false
    
    private var contentLength: CGFloat {
        return usesLargerStyle ? 37 : 20
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: contentLength, height: contentLength)
    }
    
    override var tintColor: UIColor! {
        didSet {
            if let indicator = indicatorLayer {
                indicator.strokeColor = tintColor.cgColor
            }
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
        if let indicatorLayer = indicatorLayer {
            indicatorLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }
    
    override func didMoveToWindow() {
        if _isAnimating {
            setupAnimation()
        }
    }
    
    func startAnimating() {
        guard !_isAnimating else {
            return
        }
        if indicatorLayer == nil {
            reloadIndicatorLayer(usesLargerStyle: usesLargerStyle)
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
        indicatorLayer.removeAllAnimations()
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
        if _isAnimating {
            indicatorLayer.removeAllAnimations()
        }
    }
    
    @objc private func applicationWillEnterForeground() {
        if _isAnimating {
            setupAnimation()
        }
    }
    
    private func reloadIndicatorLayer(usesLargerStyle: Bool) {
        if let old = indicatorLayer {
            old.removeFromSuperlayer()
        }
        indicatorLayer = CAShapeLayer()
        indicatorLayer.backgroundColor = UIColor.clear.cgColor
        indicatorLayer.strokeColor = tintColor.cgColor
        indicatorLayer.fillColor = UIColor.clear.cgColor
        indicatorLayer.lineWidth = usesLargerStyle ? 3 : 2
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
        setNeedsLayout()
    }
    
    private func setupAnimation() {
        guard window != nil else {
            return
        }
        let anim = CABasicAnimation(keyPath: "transform.rotation.z")
        anim.toValue = CGFloat.pi * 2
        anim.duration = 2
        anim.repeatCount = .infinity
        indicatorLayer.add(anim, forKey: "rotation")
    }
    
}
