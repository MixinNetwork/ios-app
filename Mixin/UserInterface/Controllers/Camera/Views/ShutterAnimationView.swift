import UIKit

class ShutterAnimationView: UIView {
    
    static let shutterSize = CGSize(width: 72, height: 72)
    static let sendSize = CGSize(width: 44, height: 44)
    static let shutterLineWidth: CGFloat = 7
    static let animationDuration: TimeInterval = 0.3
    
    private let shutterLayer = CAShapeLayer()
    private let sendImageView = UIImageView(image: R.image.ic_camera_send())
    private let shutterPath: CGPath = {
        let frame = CGRect(origin: .zero, size: shutterSize)
            .insetBy(dx: shutterLineWidth / 2, dy: shutterLineWidth / 2)
        return UIBezierPath(ovalIn: frame).cgPath
    }()
    private let sendPath = UIBezierPath(ovalIn: CGRect(x: (shutterSize.width - sendSize.width / 2) / 2,
                                                       y: (shutterSize.height - sendSize.height / 2) / 2,
                                                       width: sendSize.width / 2,
                                                       height: sendSize.height / 2)).cgPath
    private let shutterStrokeColor = UIColor.white.cgColor
    private let shutterFillColor = UIColor.clear.cgColor
    private let sendColor = UIColor.cameraSendBlue.cgColor
    
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
        shutterLayer.frame = CGRect(x: (bounds.width - ShutterAnimationView.shutterSize.width) / 2,
                                    y: (bounds.height - ShutterAnimationView.shutterSize.height) / 2,
                                    width: ShutterAnimationView.shutterSize.width,
                                    height: ShutterAnimationView.shutterSize.height)
        sendImageView.frame = bounds
    }
    
    func transformToSend() {
        shutterLayer.removeAllAnimations()
        shutterLayer.path = shutterPath
        shutterLayer.strokeColor = shutterStrokeColor
        shutterLayer.fillColor = shutterFillColor
        shutterLayer.lineWidth = ShutterAnimationView.shutterLineWidth
        shutterLayer.opacity = 1
        sendImageView.alpha = 0

        let duration = ShutterAnimationView.animationDuration
        let pathAnimation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.path))
        pathAnimation.toValue = sendPath
        let strokeColorAnimation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.strokeColor))
        strokeColorAnimation.toValue = sendColor
        let lineWidthAnimation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.lineWidth))
        lineWidthAnimation.toValue = ShutterAnimationView.sendSize.width / 2
        let transformAnimations = [pathAnimation, strokeColorAnimation, lineWidthAnimation]
        for anim in transformAnimations {
            anim.duration = duration * 0.7
            anim.fillMode = .both
            anim.isRemovedOnCompletion = false
            shutterLayer.add(anim, forKey: anim.keyPath)
        }
        
        let shutterAlphaAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        shutterAlphaAnimation.toValue = 0
        shutterAlphaAnimation.beginTime = CACurrentMediaTime() + duration * 0.7
        shutterAlphaAnimation.duration = duration * 0.3
        shutterAlphaAnimation.fillMode = .both
        shutterAlphaAnimation.isRemovedOnCompletion = false
        shutterLayer.add(shutterAlphaAnimation, forKey: shutterAlphaAnimation.keyPath)
        UIView.animate(withDuration: duration * 0.3, delay: duration * 0.7, options: [], animations: {
            self.sendImageView.alpha = 1
        }, completion: nil)
    }
    
    func transformToShutter() {
        shutterLayer.removeAllAnimations()
        shutterLayer.path = sendPath
        shutterLayer.strokeColor = sendColor
        shutterLayer.lineWidth = ShutterAnimationView.sendSize.width / 2
        shutterLayer.opacity = 0
        sendImageView.alpha = 1
        
        let duration = ShutterAnimationView.animationDuration
        let shutterAlphaAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        shutterAlphaAnimation.toValue = 1
        shutterAlphaAnimation.duration = duration * 0.3
        shutterAlphaAnimation.fillMode = .both
        shutterAlphaAnimation.isRemovedOnCompletion = false
        shutterLayer.add(shutterAlphaAnimation, forKey: shutterAlphaAnimation.keyPath)
        UIView.animate(withDuration: duration * 0.3) {
            self.sendImageView.alpha = 0
        }
        
        let pathAnimation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.path))
        pathAnimation.toValue = shutterPath
        let strokeColorAnimation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.strokeColor))
        strokeColorAnimation.toValue = shutterStrokeColor
        let lineWidthAnimation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.lineWidth))
        lineWidthAnimation.toValue = ShutterAnimationView.shutterLineWidth
        let transformAnimations = [pathAnimation, strokeColorAnimation, lineWidthAnimation]
        for anim in transformAnimations {
            anim.beginTime = CACurrentMediaTime() + duration * 0.3
            anim.duration = duration * 0.7
            anim.fillMode = .both
            anim.isRemovedOnCompletion = false
            shutterLayer.add(anim, forKey: anim.keyPath)
        }
    }
    
    private func prepare() {
        shutterLayer.path = shutterPath
        shutterLayer.strokeColor = shutterStrokeColor
        shutterLayer.fillColor = UIColor.clear.cgColor
        shutterLayer.lineWidth = ShutterAnimationView.shutterLineWidth
        shutterLayer.masksToBounds = true
        layer.addSublayer(shutterLayer)
        sendImageView.contentMode = .center
        sendImageView.alpha = 0
        addSubview(sendImageView)
    }
    
}
