import UIKit

class GroupCallMemberConnectingView: UIView {
    
    override var isHidden: Bool {
        didSet {
            isHidden ? stopAnimating() : startAnimating()
        }
    }
    
    private let dotLength: CGFloat = 6
    private let dotSpacing: CGFloat = 4
    
    private var dotLayers = [CALayer]()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSublayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSublayers()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        dotLayers[0].position = CGPoint(x: bounds.midX - dotSpacing - dotLength,
                                        y: bounds.midY)
        dotLayers[1].position = CGPoint(x: bounds.midX,
                                        y: bounds.midY)
        dotLayers[2].position = CGPoint(x: bounds.midX + dotSpacing + dotLength,
                                        y: bounds.midY)
    }
    
    private func loadSublayers() {
        for _ in 0...2 {
            let dotLayer = CALayer()
            dotLayer.frame.size = CGSize(width: dotLength, height: dotLength)
            dotLayer.cornerRadius = dotLength / 2
            dotLayer.backgroundColor = UIColor.white.withAlphaComponent(0.6).cgColor
            layer.addSublayer(dotLayer)
            dotLayers.append(dotLayer)
        }
    }
    
    private func startAnimating() {
        for (index, layer) in dotLayers.enumerated() {
            let delay = TimeInterval(index) * 0.1
            let animation = makeFadingAnimation(delay: delay)
            layer.add(animation, forKey: #keyPath(CALayer.opacity))
        }
    }
    
    private func stopAnimating() {
        for layer in dotLayers {
            layer.removeAllAnimations()
        }
    }
    
    private func makeFadingAnimation(delay: TimeInterval) -> CAAnimation {
        let anim = CAKeyframeAnimation(keyPath: #keyPath(CALayer.opacity))
        anim.autoreverses = true
        anim.repeatCount = .greatestFiniteMagnitude
        anim.beginTime = CACurrentMediaTime() + delay
        anim.duration = 1.5
        anim.keyTimes = [0, 0.5, 1]
        anim.values = [1, 0.5, 1]
        return anim
    }
    
}
