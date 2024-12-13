import UIKit
import MixinServices

class CreateRecoveryContactVerificationCodeViewController: VerificationCodeViewController {

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
        helpButton.setTitle(R.string.localizable.cant_receive_the_code(), for: .normal)
        helpButton.setTitleColor(R.color.red(), for: .normal)
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
        titleLabel.text = R.string.localizable.setting_emergency_send_code(identityNumber)
    }

     @objc func helpAction() {
        UIApplication.shared.open(URL.recoveryContact, options: [:], completionHandler: nil)
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
        EmergencyAPI.verifyContact(pin: pin, id: verificationId, code: verificationCodeField.text) { [weak self] (result) in
            switch result {
            case .success(let account):
                let hadEmergencyContact = LoginManager.shared.account?.hasEmergencyContact ?? false
                LoginManager.shared.setAccount(account)
                self?.showSuccessAlert(hadEmergencyContact: hadEmergencyContact)
            case .failure(let error):
                if PINVerificationFailureHandler.canHandle(error: error) {
                    PINVerificationFailureHandler.handle(error: error) { [weak self] (description) in
                        self?.alert(description)
                    }
                } else {
                    self?.handleVerificationCodeError(error)
                }
            }
            self?.isBusy = false
        }
    }
    
    private func showSuccessAlert(hadEmergencyContact: Bool) {
        let title: String
        if hadEmergencyContact {
            title = R.string.localizable.your_emergency_contact_has_been_changed()
        } else {
            title = R.string.localizable.set_emergency_create_successfully()
        }
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.ok(), style: .default, handler: { (_) in
            guard let navigationController = self.navigationController else {
                return
            }
            var viewControllers = navigationController.viewControllers
            if let index = viewControllers.firstIndex(where: { $0 is RecoveryKitViewController }) {
                viewControllers.removeLast(viewControllers.count - index - 1)
            }
            viewControllers.append(ViewRecoveryContactViewController())
            navigationController.setViewControllers(viewControllers, animated: true)
        }))
        present(alert, animated: true, completion: nil)
    }
    
}
