import UIKit

class BotItemCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: AvatarImageView!
    @IBOutlet weak var label: UILabel?
    @IBOutlet weak var iconContainerView: UIView?
    
    var isShaking = false
    
    var item: BotItem? {
        didSet {
            updateUI()
        }
    }
    
    var snapshotView: UIView {
        return contentView.snapshotView(afterScreenUpdates: true) ?? UIView()
    }
    
    func enterEditingMode() {
        
    }
    
    func leaveEditingMode() {
        
    }
    
    func updateUI() {
        guard let item = item else { return }
        label?.text = item.name
        label?.isHidden = false
        if let item = item as? Bot {
            //imageView.setImage(app: <#T##App#>)
            //TODO: ‼️ fix
            imageView.image = UIImage(named: "ic_camera_send")
        }
    }
    
}

extension BotItemCell {
    
    func startShaking() {
        guard !isShaking else { return }
        isShaking = true
        
        let positionAnimation = CAKeyframeAnimation(keyPath: "position")
        positionAnimation.values = [CGPoint(x: -1, y: -1),
                                    CGPoint(x: 0, y: 0),
                                    CGPoint(x: -1, y: 0),
                                    CGPoint(x: 0, y: -1),
                                    CGPoint(x: -1, y: -1)]
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
        
        contentView.layer.add(animationGroup, forKey: "Shaking_Animation")
    }
    
    func stopShaking() {
        isShaking = false
        contentView.layer.removeAllAnimations()
        contentView.transform = .identity
    }
    
}
