import UIKit

class FullScreenPopupEdgePanGestureRecognizer: UIScreenEdgePanGestureRecognizer {
    
    static let decisionDistance: CGFloat = UIScreen.main.bounds.width / 4
    
    private(set) var fractionComplete: CGFloat = 0
    
    private var beganTranslation = CGPoint.zero
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        fractionComplete = 0
        super.touchesBegan(touches, with: event)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let translation = self.translation(in: view)
        var shouldEnd = false
        fractionComplete = min(1, max(0, translation.x / FullScreenPopupEdgePanGestureRecognizer.decisionDistance))
        if translation.x > FullScreenPopupEdgePanGestureRecognizer.decisionDistance {
            shouldEnd = true
        }
        super.touchesMoved(touches, with: event)
        if shouldEnd {
            state = .ended
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if fractionComplete > 0.99 {
            super.touchesEnded(touches, with: event)
        } else {
            super.touchesCancelled(touches, with: event)
        }
    }
    
}
