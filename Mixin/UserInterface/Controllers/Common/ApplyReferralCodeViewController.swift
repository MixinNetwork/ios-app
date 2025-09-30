import UIKit

final class ApplyReferralCodeViewController: UIViewController {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var inputSectionView: UIView!
    @IBOutlet weak var codeFieldTitleLabel: UILabel!
    @IBOutlet weak var codeField: UITextField!
    @IBOutlet weak var startInputButton: UIButton!
    @IBOutlet weak var benefitLabel: UILabel!
    @IBOutlet weak var errorDescriptionLabel: UILabel!
    @IBOutlet weak var confirmButton: ConfigurationBasedBusyButton!
    @IBOutlet weak var laterButton: UIButton!
    
    private let initialCode: String?
    private let codeCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
    private let codeCount = 8
    
    private var isBusy = false {
        didSet {
            confirmButton.isBusy = isBusy
            laterButton.isEnabled = !isBusy
        }
    }
    
    init(code: String?) {
        self.initialCode = code
        let nib = R.nib.applyReferralCodeView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presentationController?.delegate = self
        
        titleLabel.text = R.string.localizable.apply_referral_code()
        contentStackView.setCustomSpacing(32, after: titleLabel)
        
        inputSectionView.layer.cornerRadius = 8
        inputSectionView.layer.masksToBounds = true
        codeFieldTitleLabel.text = R.string.localizable.referral_code()
        codeFieldTitleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        codeField.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 16, weight: .semibold)
        )
        codeField.adjustsFontForContentSizeCategory = true
        if let initialCode, !initialCode.isEmpty {
            codeField.text = initialCode
            startInputButton.isHidden = true
        }
        codeField.delegate = self
        benefitLabel.text = R.string.localizable.apply_referral_code_benefit()
        startInputButton.configuration?.title = R.string.localizable.referral_code()
        
        confirmButton.configuration?.attributedTitle = {
            var attributes = AttributeContainer()
            attributes.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 16, weight: .medium)
            )
            attributes.foregroundColor = .white
            return AttributedString(
                R.string.localizable.confirm(),
                attributes: attributes
            )
        }()
        confirmButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        laterButton.configuration?.attributedTitle = {
            var attributes = AttributeContainer()
            attributes.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 16, weight: .medium)
            )
            attributes.foregroundColor = R.color.theme()
            return AttributedString(
                R.string.localizable.later(),
                attributes: attributes
            )
        }()
        laterButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        detectCode()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(detectCode),
            name: UITextField.textDidChangeNotification,
            object: codeField
        )
    }
    
    @IBAction func startInput(_ sender: Any) {
        startInputButton.isHidden = true
        codeField.becomeFirstResponder()
    }
    
    @IBAction func confirm(_ sender: Any) {
        guard let code = codeField.text?.uppercased() else {
            return
        }
        errorDescriptionLabel.isHidden = true
        isBusy = true
        RouteAPI.bindReferral(code: code) { [weak self] result in
            guard let self else {
                return
            }
            self.isBusy = false
            switch result {
            case .success:
                let success = ReferralCodeAppliedViewController()
                self.addChild(success)
                self.view.addSubview(success.view)
                success.view.snp.makeEdgesEqualToSuperview()
            case .failure(let error):
                self.errorDescriptionLabel.text = error.localizedDescription
                self.errorDescriptionLabel.isHidden = false
            }
        }
    }
    
    @IBAction func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @objc private func detectCode() {
        if let code = codeField.text,
           code.count == codeCount,
           code.unicodeScalars.allSatisfy(codeCharacters.contains(_:))
        {
            confirmButton.isEnabled = true
        } else {
            confirmButton.isEnabled = false
        }
    }
    
}

extension ApplyReferralCodeViewController: UITextFieldDelegate {
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        if textField.text?.isEmpty ?? true {
            startInputButton.isHidden = false
        }
        codeField.text = codeField.text?.uppercased()
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard string.isEmpty || string.unicodeScalars.allSatisfy(codeCharacters.contains(_:)) else {
            return false
        }
        let text = (textField.text ?? "") as NSString
        let newText = text.replacingCharacters(in: range, with: string)
        return newText.count <= codeCount
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
}

extension ApplyReferralCodeViewController: UIAdaptivePresentationControllerDelegate {
    
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        !isBusy
    }
    
}
