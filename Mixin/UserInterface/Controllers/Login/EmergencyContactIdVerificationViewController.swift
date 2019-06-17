import UIKit

class EmergencyContactIdVerificationViewController: LoginInfoInputViewController {
    
    var context: LoginContext!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.navigation_title_enter_emergency_contact_id()
        textField.textAlignment = .center
        textField.keyboardType = .numberPad
        textField.delegate = self
    }
    
    override func continueAction(_ sender: Any) {
        continueButton.isBusy = true
        var context = self.context!
        let identityNumber = self.trimmedText
        EmergencyAPI.shared.createSession(phoneNumber: context.fullNumber, identityNumber: identityNumber) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case .success(let response):
                context.verificationId = response.id
                let vc = EmergencyContactLoginVerificationCodeViewController()
                vc.context = context
                vc.emergencyContactIdentityNumber = identityNumber
                weakSelf.navigationController?.pushViewController(vc, animated: true)
            case .failure(let error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
            weakSelf.continueButton.isBusy = false
        }
    }
    
}

extension EmergencyContactIdVerificationViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return string.isEmpty || string.isNumeric
    }
    
}
