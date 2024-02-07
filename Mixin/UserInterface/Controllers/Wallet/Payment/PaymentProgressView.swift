import UIKit

final class PaymentProgressView: UIView {
    
    enum Progress {
        case busy
        case success
        case failure
    }
    
    private let ringLayer = CAShapeLayer()
    private let ringStrokeEnd: CGFloat = 0.8
    
    private var progress: Progress = .busy
    private var toppingLayer = CALayer()
    
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
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        ringLayer.position = center
        toppingLayer.position = center
    }
    
    override func didMoveToWindow() {
        startBusyAnimationIfNeeded()
    }
    
    func setProgress(_ newProgress: Progress) {
        guard newProgress != progress else {
            return
        }
        switch (progress, newProgress) {
        case (.busy, .success):
            ringLayer.strokeEnd = 1
            let strokeAnimation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.strokeEnd))
            strokeAnimation.duration = 0.2
            strokeAnimation.fromValue = ringStrokeEnd
            strokeAnimation.toValue = 1
            ringLayer.add(strokeAnimation, forKey: "stroke_end")
            
            ringLayer.strokeColor = UIColor(rgbValue: 0x27AE60).cgColor
            let colorAnimation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.strokeColor))
            colorAnimation.duration = 0.2
            colorAnimation.fromValue = R.color.theme()!.cgColor
            colorAnimation.toValue = ringLayer.strokeColor
            ringLayer.add(colorAnimation, forKey: "stroke_color")
            
            let checkmark = R.image.payment_progress_checkmark()!
            toppingLayer.contents = checkmark.cgImage
            toppingLayer.frame.size = checkmark.size
            toppingLayer.opacity = 1
            let opacityAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
            opacityAnimation.duration = 0.2
            opacityAnimation.fromValue = 0
            opacityAnimation.toValue = 1
            toppingLayer.add(colorAnimation, forKey: "opacity")
            setNeedsLayout()
            layoutIfNeeded()
        case (.busy, .failure):
            ringLayer.strokeEnd = 1
            let strokeAnimation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.strokeEnd))
            strokeAnimation.duration = 0.2
            strokeAnimation.fromValue = ringStrokeEnd
            strokeAnimation.toValue = 1
            ringLayer.add(strokeAnimation, forKey: "stroke_end")
            
            ringLayer.strokeColor = UIColor(rgbValue: 0xF6A417).cgColor
            let colorAnimation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.strokeColor))
            colorAnimation.duration = 0.2
            colorAnimation.fromValue = R.color.theme()!.cgColor
            colorAnimation.toValue = ringLayer.strokeColor
            ringLayer.add(colorAnimation, forKey: "stroke_color")
            
            let warning = R.image.payment_progress_warning()!
            toppingLayer.contents = warning.cgImage
            toppingLayer.frame.size = warning.size
            toppingLayer.opacity = 1
            let opacityAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
            opacityAnimation.duration = 0.2
            opacityAnimation.fromValue = 0
            opacityAnimation.toValue = 1
            toppingLayer.add(colorAnimation, forKey: "opacity")
            setNeedsLayout()
            layoutIfNeeded()
        case (_, .busy):
            ringLayer.strokeEnd = ringStrokeEnd
            let strokeAnimation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.strokeEnd))
            strokeAnimation.duration = 0.2
            strokeAnimation.fromValue = 1
            strokeAnimation.toValue = ringStrokeEnd
            ringLayer.add(strokeAnimation, forKey: "stroke_end")
            
            ringLayer.strokeColor = R.color.theme()!.cgColor
            let colorAnimation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.strokeColor))
            colorAnimation.duration = 0.2
            colorAnimation.fromValue = R.color.theme()!.cgColor
            colorAnimation.toValue = ringLayer.strokeColor
            ringLayer.add(colorAnimation, forKey: "stroke_color")
            
            toppingLayer.opacity = 0
            toppingLayer.contents = nil
        default:
            fatalError()
        }
        progress = newProgress
    }
    
    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(removeRingLayerAnimations),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(startBusyAnimationIfNeeded),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        
        let dimension: CGFloat = 50
        ringLayer.backgroundColor = UIColor.clear.cgColor
        ringLayer.strokeColor = R.color.theme()!.cgColor
        ringLayer.fillColor = UIColor.clear.cgColor
        ringLayer.lineWidth = 4
        ringLayer.lineCap = .round
        ringLayer.strokeStart = 0
        ringLayer.strokeEnd = ringStrokeEnd
        ringLayer.bounds = CGRect(x: 0, y: 0, width: dimension, height: dimension)
        ringLayer.path = UIBezierPath(arcCenter: CGPoint(x: dimension / 2, y: dimension / 2),
                                      radius: dimension / 2,
                                      startAngle: 0,
                                      endAngle: .pi * 2,
                                      clockwise: true).cgPath
        layer.addSublayer(ringLayer)
        layer.addSublayer(toppingLayer)
        setNeedsLayout()
    }
    
    @objc private func removeRingLayerAnimations() {
        ringLayer.removeAllAnimations()
    }
    
    @objc private func startBusyAnimationIfNeeded() {
        guard progress == .busy && window != nil else {
            return
        }
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.toValue = CGFloat.pi * 2
        animation.duration = 0.8
        animation.repeatCount = .infinity
        ringLayer.add(animation, forKey: "rotation")
    }
    
}
