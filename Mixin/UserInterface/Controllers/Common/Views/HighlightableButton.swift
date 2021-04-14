import UIKit

class HighlightableButton: UIButton {
    
    @IBInspectable var normalColor: UIColor? = nil {
        didSet {
            if !isHighlighted {
                backgroundColor = normalColor
            }
        }
    }
    
    @IBInspectable var highlightedColor: UIColor? = nil {
        didSet {
            if isHighlighted {
                backgroundColor = highlightedColor
            }
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                backgroundColor = highlightedColor
            } else {
                backgroundColor = normalColor
            }
        }
    }
    
}
