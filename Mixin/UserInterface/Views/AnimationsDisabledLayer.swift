import UIKit

class AnimationsDisabledLayer: CALayer {
    
    override func action(forKey event: String) -> CAAction? {
        nil
    }
    
}
