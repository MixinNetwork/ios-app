import UIKit

class LoginInfoInputViewController: UIViewController {
    
    enum Style {
        case primary
        case secondary
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var inputBoxView: UIView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var continueButton: StyledButton!
    
    var trimmedText: String {
        textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    private let style: Style
    
    init(style: Style) {
        self.style = style
        let nib = R.nib.loginInfoInputView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        switch style {
        case .primary:
            view.backgroundColor = R.color.background()
            inputBoxView.backgroundColor = R.color.background_input()
        case .secondary:
            view.backgroundColor = R.color.background_secondary()
            inputBoxView.backgroundColor = R.color.background()
        }
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
