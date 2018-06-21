import UIKit

class ShutterAnimationView: UIView {
    
    static let shutterSize = CGSize(width: 72, height: 72)
    static let sendSize = #imageLiteral(resourceName: "ic_camera_send").size
    static let shutterLineWidth: CGFloat = 3
    static let animationDuration: TimeInterval = 0.3

    private let shutterLayer = CAShapeLayer()
    private let sendLayer = CALayer()
    private let shutterPath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: shutterSize).insetBy(dx: shutterLineWidth, dy: shutterLineWidth)).cgPath
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
        sendLayer.frame = CGRect(x: (bounds.width - ShutterAnimationView.sendSize.width) / 2,
                                 y: (bounds.height - ShutterAnimationView.sendSize.height) / 2,
                                 width: ShutterAnimationView.sendSize.width,
                                 height: ShutterAnimationView.sendSize.height)
    }
    
    func transformToSend() {
        shutterLayer.removeAllAnimations()
        shutterLayer.path = shutterPath
        shutterLayer.strokeColor = shutterStrokeColor
        shutterLayer.fillColor = shutterFillColor
        shutterLayer.lineWidth = ShutterAnimationView.shutterLineWidth
        shutterLayer.opacity = 1
        sendLayer.removeAllAnimations()
        sendLayer.opacity = 0

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
            anim.fillMode = kCAFillModeBoth
            anim.isRemovedOnCompletion = false
            shutterLayer.add(anim, forKey: anim.keyPath)
        }
        
        let shutterAlphaAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        shutterAlphaAnimation.toValue = 0
        let sendAlphaAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        sendAlphaAnimation.toValue = 1
        let alphaAnimations = [shutterAlphaAnimation, sendAlphaAnimation]
        for anim in alphaAnimations {
            anim.beginTime = CACurrentMediaTime() + duration * 0.7
            anim.duration = duration * 0.3
            anim.fillMode = kCAFillModeBoth
            anim.isRemovedOnCompletion = false
        }
        shutterLayer.add(shutterAlphaAnimation, forKey: shutterAlphaAnimation.keyPath)
        sendLayer.add(sendAlphaAnimation, forKey: sendAlphaAnimation.keyPath)
    }
    
    func transformToShutter() {
        shutterLayer.removeAllAnimations()
        shutterLayer.path = sendPath
        shutterLayer.strokeColor = sendColor
        shutterLayer.lineWidth = ShutterAnimationView.sendSize.width / 2
        shutterLayer.opacity = 0
        sendLayer.removeAllAnimations()
        sendLayer.opacity = 1
        
        let duration = ShutterAnimationView.animationDuration
        let shutterAlphaAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        shutterAlphaAnimation.toValue = 1
        let sendAlphaAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        sendAlphaAnimation.toValue = 0
        let alphaAnimations = [shutterAlphaAnimation, sendAlphaAnimation]
        for anim in alphaAnimations {
            anim.duration = duration * 0.3
            anim.fillMode = kCAFillModeBoth
            anim.isRemovedOnCompletion = false
        }
        shutterLayer.add(shutterAlphaAnimation, forKey: shutterAlphaAnimation.keyPath)
        sendLayer.add(sendAlphaAnimation, forKey: sendAlphaAnimation.keyPath)
        
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
            anim.fillMode = kCAFillModeBoth
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
        sendLayer.contents = #imageLiteral(resourceName: "ic_camera_send").cgImage
        sendLayer.opacity = 0
        layer.addSublayer(sendLayer)
    }
    
}
