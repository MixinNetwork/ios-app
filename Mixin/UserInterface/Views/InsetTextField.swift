import UIKit

class InsetTextField: UITextField {
    
    private let inset: CGFloat = 16
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.textRect(forBounds: bounds)
        return CGRect(x: rect.origin.x + inset,
                      y: rect.origin.y,
                      width: rect.width - inset * 2,
                      height: rect.height)
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.editingRect(forBounds: bounds)
        return CGRect(x: rect.origin.x + inset,
                      y: rect.origin.y,
                      width: rect.width - inset * 2,
                      height: rect.height)
    }
    
}
