import UIKit

class LayoutConstraintHairline: NSLayoutConstraint {

    override func awakeFromNib() {
        super.awakeFromNib()
        constant = 1 / UIScreen.main.scale
    }
    
}
