import UIKit

class SearchBoxTextField: UITextField {
    
    let textMargin: CGFloat = 16
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.textRect(forBounds: bounds)
        return CGRect(x: rect.origin.x + textMargin,
                      y: rect.origin.y,
                      width: rect.width - textMargin,
                      height: rect.height)
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.editingRect(forBounds: bounds)
        return CGRect(x: rect.origin.x + textMargin,
                      y: rect.origin.y,
                      width: rect.width - textMargin,
                      height: rect.height)
    }
    
}
