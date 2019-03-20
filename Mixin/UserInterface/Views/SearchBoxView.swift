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
    
    @IBOutlet weak var textField: UITextField!
    
    let height: CGFloat = 40
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    @objc func clear(_ sender: Any) {
        textField.text = nil
        textField.sendActions(for: .editingChanged)
    }
    
    private func prepare() {
        loadXib()
        let magnifyingGlassImage = UIImage(named: "Wallet/ic_search")
        textField.leftView = UIImageView(image: magnifyingGlassImage)
        textField.leftViewMode = .always
        let clearButton = UIButton(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
        clearButton.addTarget(self, action: #selector(clear(_:)), for: .touchUpInside)
        let clearImage = UIImage(named: "Wallet/ic_clear")
        clearButton.imageView?.contentMode = .center
        clearButton.setImage(clearImage, for: .normal)
        textField.rightView = clearButton
        textField.rightViewMode = .whileEditing
        clearButton.frame = textField.rightViewRect(forBounds: textField.bounds)
    }
    
}
