import UIKit
import MapKit

class UserLocationAnnotationView: MKAnnotationView {
    
    private let pulseAnimationDuration: CFTimeInterval = 3
    
    private lazy var pulseLayer: CALayer = {
        let layer = CALayer()
        let sideLength: CGFloat = 120
        layer.bounds = CGRect(x: 0, y: 0, width: sideLength, height: sideLength)
        layer.position = CGPoint(x: bounds.midX, y: self.bounds.midY)
        layer.backgroundColor = UIColor.theme.cgColor
        layer.cornerRadius = sideLength / 2
        return layer
    }()
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        image = R.image.conversation.ic_annotation_user_location()
        layer.insertSublayer(pulseLayer, at: 0)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        image = R.image.conversation.ic_annotation_user_location()
        layer.insertSublayer(pulseLayer, at: 0)
    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        pulseLayer.removeAllAnimations()
        if newSuperview != nil {
            let group = CAAnimationGroup()
            group.duration = pulseAnimationDuration
            group.repeatCount = .infinity
            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale.xy")
            scaleAnimation.fromValue = 0
            scaleAnimation.toValue = 1
            let opacityAnimation = CAKeyframeAnimation(keyPath: #keyPath(CALayer.opacity))
            opacityAnimation.values = [0.45, 0.45, 0]
            opacityAnimation.keyTimes = [0, 0.2, 1]
            group.animations = [scaleAnimation, opacityAnimation]
            pulseLayer.add(group, forKey: "pulse")
        }
    }
    
}
