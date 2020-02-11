import UIKit

class ContactMessageViewModel: CardMessageViewModel {
    
    override class var supportsQuoting: Bool {
        true
    }
    
    override var contentWidth: CGFloat {
        235
    }
    
}
