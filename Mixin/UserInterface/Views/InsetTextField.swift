import UIKit

class InsetTextField: UITextField {
    
    var insets: UIEdgeInsets {
        didSet {
            setNeedsLayout()
            layoutIfNeeded()
        }
    }
    
    init(frame: CGRect, insets: UIEdgeInsets) {
        self.insets = insets
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        self.insets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        super.init(coder: coder)
    }
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        super.textRect(forBounds: bounds).inset(by: insets)
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        super.editingRect(forBounds: bounds).inset(by: insets)
    }
    
}
