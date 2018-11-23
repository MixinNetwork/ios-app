import UIKit

class LargerSearchBoxView: UIView, XibDesignable {
    
    @IBOutlet weak var textFieldBackgroundView: UIView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var clearButton: UIButton!
    
    private var isEditing = false
    
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
        isEditing = true
        textFieldBackgroundView.isHidden = false
    }
    
    @objc func textDidEndEditing(_ notification: Notification) {
        guard let textField = notification.object as? UITextField, textField == self.textField else {
            return
        }
        isEditing = false
        textFieldBackgroundView.isHidden = true
    }
    
    @objc func textDidChange(_ notification: Notification) {
        guard let textField = notification.object as? UITextField, textField == self.textField else {
            return
        }
        if let text = textField.text, !text.isEmpty {
            clearButton.isHidden = false
        } else {
            clearButton.isHidden = true
        }
    }
    
    @IBAction func clearAction(_ sender: Any) {
        textField.text = nil
        textField.sendActions(for: .editingChanged)
        clearButton.isHidden = true
    }
    
    private func prepare() {
        loadXib()
        clearButton.imageView?.contentMode = .center
        NotificationCenter.default.addObserver(self, selector: #selector(textDidBeginEditing(_:)), name: UITextField.textDidBeginEditingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(textDidEndEditing(_:)), name: UITextField.textDidEndEditingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: nil)
    }
    
}
