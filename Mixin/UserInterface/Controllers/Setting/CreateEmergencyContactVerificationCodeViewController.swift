import UIKit

class CreateEmergencyContactVerificationCodeViewController: VerificationCodeViewController {

    private let helpButton = UIButton(type: .custom)
    private var helpButtonBottomConstraint: NSLayoutConstraint!

    private var pin = ""
    private var verificationId = ""
    private var identityNumber = ""
    
    convenience init(pin: String, verificationId: String, identityNumber: String) {
        self.init()
        self.pin = pin
        self.verificationId = verificationId
        self.identityNumber = identityNumber
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        helpButton.setTitle(R.string.localizable.button_title_cant_receive_code(), for: .normal)
        helpButton.setTitleColor(.walletRed, for: .normal)
        helpButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        helpButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        helpButton.addTarget(self, action: #selector(helpAction), for: .touchUpInside)
        helpButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(helpButton)
        helpButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        helpButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        helpButtonBottomConstraint = helpButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0)
        helpButtonBottomConstraint.isActive = true
        
        resendButton.isHidden = true
        titleLabel.text = Localized.NAVIGATION_TITLE_ENTER_EMERGENCY_CONTACT_VERIFICATION_CODE(id: identityNumber)
    }

     @objc func helpAction() {
        UIApplication.shared.open(URL.emergencyContact, options: [:], completionHandler: nil)
    }

    override func layout(for keyboardFrame: CGRect) {
        super.layout(for: keyboardFrame)
        helpButtonBottomConstraint.constant = -keyboardFrame.height - 28
    }

    override func verificationCodeFieldEditingChanged(_ sender: Any) {
        let code = verificationCodeField.text
        let codeCountMeetsRequirement = code.count == verificationCodeField.numberOfDigits
        continueButton.isHidden = !codeCountMeetsRequirement
        if !isBusy && codeCountMeetsRequirement {
            verify()
        }
    }
    
    override func continueAction(_ sender: Any) {
        verify()
    }
    
    private func verify() {
        isBusy = true
        EmergencyAPI.shared.verifyContact(pin: pin, id: verificationId, code: verificationCodeField.text) { [weak self] (result) in
            switch result {
            case .success(let account):
                LoginManager.shared.account = account
                self?.showSuccessAlert()
            case .failure(let error):
                if error.code == 429 {
                    self?.alert(R.string.localizable.wallet_password_too_many_requests())
                } else {
                    self?.handleVerificationCodeError(error)
                }
            }
            self?.isBusy = false
        }
    }
    
    private func showSuccessAlert() {
        let title = R.string.localizable.setting_change_emergency_contact_success()
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_ok(), style: .default, handler: { (_) in
            self.navigationController?.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }
    
}
