import UIKit

class SearchBoxView: UIView, XibDesignable {
    
    @IBOutlet weak var textField: SearchBoxTextField!
    
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
    
    var isBusy = false {
        didSet {
            textFieldLeftView.isBusy = isBusy
        }
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
        loadXib()
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
