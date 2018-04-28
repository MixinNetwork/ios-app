import UIKit

class ResignationRefusingTextField: UITextField {
    
    var allowsResigning: Bool = true
    
    override var canResignFirstResponder: Bool {
        return allowsResigning
    }
    
}
