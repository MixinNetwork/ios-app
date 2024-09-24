import UIKit

class MenuTriggerButton: UIButton {
    
    override func menuAttachmentPoint(for configuration: UIContextMenuConfiguration) -> CGPoint {
        CGPoint(x: bounds.maxX, y: bounds.maxY)
    }
    
}
