import UIKit

class ModernSearchBoxView: UIView, XibDesignable, SearchBox {
    
    @IBOutlet weak var textFieldBackgroundView: UIView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var separatorLineView: UIView!
    
    let height: CGFloat = 70
    
    private var text: String {
        return textField.text ?? ""
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func textDidBeginEditing(_ notification: Notification) {
        guard let textField = notification.object as? UITextField, textField == self.textField else {
            return
        }
        textFieldBackgroundView.isHidden = false
        UIView.performWithoutAnimation {
            clearButton.isHidden = text.isEmpty
        }
    }
    
    @objc func textDidEndEditing(_ notification: Notification) {
        guard let textField = notification.object as? UITextField, textField == self.textField else {
            return
        }
        if text.isEmpty {
            textFieldBackgroundView.isHidden = true
        }
        UIView.performWithoutAnimation {
            clearButton.isHidden = true
        }
    }
    
    @objc func textDidChange(_ notification: Notification) {
        guard let textField = notification.object as? UITextField, textField == self.textField else {
            return
        }
        UIView.performWithoutAnimation {
            clearButton.isHidden = text.isEmpty
        }
    }
    
    @IBAction func clearAction(_ sender: Any) {
        textField.text = nil
        textField.sendActions(for: .editingChanged)
        UIView.performWithoutAnimation {
            clearButton.isHidden = true
        }
    }
    
    private func prepare() {
        loadXib()
        clearButton.imageView?.contentMode = .center
        NotificationCenter.default.addObserver(self, selector: #selector(textDidBeginEditing(_:)), name: UITextField.textDidBeginEditingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(textDidEndEditing(_:)), name: UITextField.textDidEndEditingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: nil)
    }
    
}
