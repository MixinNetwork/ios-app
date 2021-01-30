import UIKit

final class IntroTextView: LinkLocatingTextView {
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        hasLinkAttribute(on: point)
    }
    
}
