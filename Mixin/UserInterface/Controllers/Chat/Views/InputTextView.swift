import UIKit

class InputTextView: UITextView {
    
    weak var overrideNext: UIResponder?

    override var next: UIResponder? {
        if let responder = overrideNext {
            return responder
        }
        return super.next
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        prepare()
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if overrideNext != nil {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }

    private func prepare() {
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 1 / UIScreen.main.scale
        textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    }
    
}
