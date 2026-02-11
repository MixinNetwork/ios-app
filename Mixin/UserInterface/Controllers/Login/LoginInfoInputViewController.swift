import UIKit

class LoginInfoInputViewController: UIViewController {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var continueButton: StyledButton!
    
    var trimmedText: String {
        textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    convenience init() {
        self.init(nib: R.nib.loginInfoInputView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentStackView.setCustomSpacing(18, after: titleLabel)
        continueButton.setTitle(R.string.localizable.continue(), for: .normal)
        continueButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        continueButton.style = .filled
        continueButton.applyDefaultContentInsets()
        continueButton.snp.makeConstraints { make in
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
                .offset(-20)
                .priority(.high)
        }
    }
    
    @IBAction func editingChangedAction(_ sender: Any) {
        continueButton.isHidden = trimmedText.isEmpty
    }
    
    @IBAction func continueToNext(_ sender: Any) {
        
    }
    
}
