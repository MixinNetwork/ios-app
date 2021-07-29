import UIKit

class ShakableCell: UICollectionViewCell {
    
    private var isShaking = false
    
    override func prepareForReuse() {
        super.prepareForReuse()
        isShaking = false
    }
    
    func startShaking() {
        guard !isShaking else {
            return
        }
        isShaking = true
        let positionAnimation = CAKeyframeAnimation(keyPath: "position")
        positionAnimation.values = [
            CGPoint(x: -1, y: -1),
            CGPoint(x: 0, y: 0),
            CGPoint(x: -1, y: 0),
            CGPoint(x: 0, y: -1),
            CGPoint(x: -1, y: -1)
        ]
        positionAnimation.calculationMode = .linear
        positionAnimation.isAdditive = true
        let transformAnimation = CAKeyframeAnimation(keyPath: "transform")
        transformAnimation.valueFunction = CAValueFunction(name: .rotateZ)
        transformAnimation.values = [-0.03525565, 0.03525565, -0.03525565]
        transformAnimation.calculationMode = .linear
        transformAnimation.isAdditive = true
        let animationGroup = CAAnimationGroup()
        animationGroup.duration = 0.25
        animationGroup.repeatCount = .infinity
        animationGroup.isRemovedOnCompletion = false
        animationGroup.beginTime = Double(arc4random() % 25) / 100.0
        animationGroup.animations = [positionAnimation, transformAnimation]
        animationGroup.isRemovedOnCompletion = false
        contentView.layer.add(animationGroup, forKey: "shakingAnimation")
    }
    
    func stopShaking() {
        isShaking = false
        contentView.layer.removeAllAnimations()
        contentView.transform = .identity
    }
    
}
