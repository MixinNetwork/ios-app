import UIKit

class DepositFieldCopyButton: RoundedButton {
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let horizontalInsets = min(0, bounds.width - 44)
        let insets = UIEdgeInsets(top: -9, left: horizontalInsets / 2, bottom: -9, right: horizontalInsets / 2)
        let bounds = self.bounds.inset(by: insets)
        return bounds.contains(point)
    }
    
}
