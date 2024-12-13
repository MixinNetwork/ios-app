import UIKit

class LoginInfoInputViewController: KeyboardBasedLayoutViewController {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var continueButton: StyledButton!
    
    @IBOutlet weak var continueButtonBottomConstraint: NSLayoutConstraint!
    
    var trimmedText: String {
        textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    convenience init() {
        self.init(nib: R.nib.loginInfoInputView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textField.becomeFirstResponder()
        continueButton.setTitle(R.string.localizable.continue(), for: .normal)
        continueButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        continueButton.style = .filled
        continueButton.applyDefaultContentInsets()
        editingChangedAction(self)
    }
    
    override func layout(for keyboardFrame: CGRect) {
        continueButtonBottomConstraint.constant = keyboardFrame.height + 20
        view.layoutIfNeeded()
    }
    
    @IBAction func editingChangedAction(_ sender: Any) {
        continueButton.isHidden = trimmedText.isEmpty
    }
    
    @IBAction func continueToNext(_ sender: Any) {
        
    }
    
}
