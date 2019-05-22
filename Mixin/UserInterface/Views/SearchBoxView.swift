import UIKit

class SearchTextField: UITextField {
    
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

class SearchBoxView: UIView, XibDesignable {
    
    @IBOutlet weak var textField: SearchTextField!
    
    var isBusy = false {
        didSet {
            if isBusy {
                textField.leftView = activityIndicator
                activityIndicator.startAnimating()
            } else {
                textField.leftView = magnifyingGlassImageView
                activityIndicator.stopAnimating()
            }
        }
    }
    
    private let clearButton = UIButton(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
    private let magnifyingGlassImageView = UIImageView(image: R.image.wallet.ic_search())
    
    private lazy var activityIndicator: ActivityIndicatorView = {
        let view = ActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        view.transform = CGAffineTransform(scaleX: 17 / 20, y: 17 / 20)
        view.tintColor = UIColor.indicatorGray
        return view
    }()
    
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
        textField.leftView = magnifyingGlassImageView
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
