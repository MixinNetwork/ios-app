import UIKit

class CreateEmergencyContactVerificationCodeViewController: VerificationCodeViewController {
    
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
        resendButton.isHidden = true
        titleLabel.text = Localized.NAVIGATION_TITLE_ENTER_EMERGENCY_CONTACT_VERIFICATION_CODE(id: identityNumber)
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
                AccountAPI.shared.account = account
                self?.showSuccessAlert()
            case .failure(let error):
                self?.handleVerificationCodeError(error)
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
