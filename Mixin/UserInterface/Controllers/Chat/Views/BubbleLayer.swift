import UIKit

class BubbleLayer: CAShapeLayer {
    
    enum Bubble {
        case none
        case left, leftWithTail
        case right, rightWithTail
        
        init(style: MessageViewModel.Style) {
            if style.contains(.tail) {
                self = style.contains(.received) ? .leftWithTail : .rightWithTail
            } else {
                self = style.contains(.received) ? .left : .right
            }
        }
    }
    
    private(set) var bubble = Bubble.none
    
    private(set) var bubbleFrame = CGRect.zero
    
    func setBubble(_ bubble: Bubble, frame: CGRect, animationDuration: TimeInterval) {
        guard bubble != self.bubble || frame != bubbleFrame else {
            return
        }
        let oldPath = path
        let (from, to) = BubblePath.path(from: self.bubble, fromFrame: bounds, to: bubble, toFrame: frame)
        path = to
        if animationDuration > 0 {
            let anim = CABasicAnimation(keyPath: #keyPath(BubbleLayer.path))
            anim.fromValue = from ?? oldPath
            anim.toValue = to
            anim.duration = animationDuration
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            add(anim, forKey: "pathAnim")
        }
        self.bubble = bubble
        self.bubbleFrame = frame
    }
    
}
