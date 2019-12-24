import UIKit

class PlaceholderTextView: UITextView {
    
    let placeholderLabel = UILabel()

    @IBInspectable
    var local_placeholder: String? {
        didSet {
            guard let key = local_placeholder, !key.isEmpty else {
                return
            }
            let localText = LocalizedString(key, comment: key)
            if localText != placeholder {
                self.placeholder = localText
            }
        }
    }
    
    @IBInspectable
    var placeholder: String? {
        didSet {
            placeholderLabel.text = placeholder
        }
    }
    
    override var textAlignment: NSTextAlignment {
        didSet {
            placeholderLabel.textAlignment = textAlignment
        }
    }
    
    override var text: String! {
        didSet {
            placeholderLabel.isHidden = !text.isEmpty
        }
    }
 
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        prepare()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func textViewDidChange(_ notification: Notification) {
        guard let textView = notification.object as? UITextView, textView == self else {
            return
        }
        placeholderLabel.isHidden = !text.isEmpty
    }
    
    private func prepare() {
        insertSubview(placeholderLabel, at: 0)
        placeholderLabel.frame = bounds
        placeholderLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        placeholderLabel.textColor = R.color.text_placeholder()
        placeholderLabel.textAlignment = textAlignment
        placeholderLabel.font = font
        placeholderLabel.adjustsFontForContentSizeCategory = adjustsFontForContentSizeCategory
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(textViewDidChange(_:)),
                                               name: UITextView.textDidChangeNotification,
                                               object: nil)
    }
    
}
