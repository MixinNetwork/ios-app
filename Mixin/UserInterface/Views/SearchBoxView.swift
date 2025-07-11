import UIKit

class SearchBoxView: UIView, XibDesignable {
    
    @IBOutlet weak var textField: InsetTextField!
    
    weak var contentView: UIView!
    
    private let clearButton = UIButton(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
    private let textFieldLeftView = SearchBoxLeftView(frame: CGRect(x: 0, y: 0, width: 17, height: 17))
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.layoutFittingExpandedSize.width, height: 40)
    }
    
    var isBusy = false {
        didSet {
            textFieldLeftView.isBusy = isBusy
        }
    }
    
    var spacesTrimmedText: String? {
        guard let text = textField.text else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
    
    var trimmedLowercaseText: String {
        (textField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func clear(_ sender: Any) {
        textField.text = nil
        textField.sendActions(for: .editingChanged)
        NotificationCenter.default.post(name: UITextField.textDidChangeNotification, object: textField)
    }
    
    @objc func textDidChange(_ notification: Notification) {
        guard (notification.object as? NSObject) == textField else {
            return
        }
        let shouldHideClearButton = textField.text.isNilOrEmpty || !textField.isEditing
        clearButton.alpha = shouldHideClearButton ? 0 : 1
    }
    
    private func prepare() {
        contentView = loadXib()
        textField.leftView = textFieldLeftView
        textField.leftViewMode = .always
        clearButton.addTarget(self, action: #selector(clear(_:)), for: .touchUpInside)
        let clearImage = UIImage(named: "Wallet/ic_clear")
        clearButton.alpha = 0
        clearButton.imageView?.contentMode = .center
        clearButton.setImage(clearImage, for: .normal)
        textField.rightView = clearButton
        textField.rightViewMode = .whileEditing
        clearButton.frame = textField.rightViewRect(forBounds: textField.bounds)
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: nil)
    }
    
}
