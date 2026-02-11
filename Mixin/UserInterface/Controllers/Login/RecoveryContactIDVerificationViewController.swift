import UIKit
import MixinServices

final class RecoveryContactIDVerificationViewController: LoginInfoInputViewController {
    
    var context: MobileNumberLoginContext
    
    init(context: MobileNumberLoginContext) {
        self.context = context
        let nib = R.nib.loginInfoInputView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.enter_your_emergency_contact_mixin_id()
        textField.textAlignment = .center
        textField.keyboardType = .numberPad
        textField.delegate = self
        textField.becomeFirstResponder()
        editingChangedAction(self)
    }
    
    override func continueToNext(_ sender: Any) {
        continueButton.isBusy = true
        var context = self.context
        let identityNumber = self.trimmedText
        EmergencyAPI.createSession(phoneNumber: context.phoneNumber, identityNumber: identityNumber) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case .success(let response):
                context.verificationID = response.id
                let vc = RecoveryContactLoginVerificationCodeViewController(context: context, identityNumber: identityNumber)
                weakSelf.navigationController?.pushViewController(vc, animated: true)
            case .failure(let error):
                Logger.login.error(category: "RecoveryContactIDVerification", message: "Failed: \(error)")
                weakSelf.alert(error.localizedDescription)
            }
            weakSelf.continueButton.isBusy = false
        }
    }
    
}

extension RecoveryContactIDVerificationViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return string.isEmpty || string.isNumeric
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if !continueButton.isHidden {
            continueToNext(textField)
        }
        return false
    }
    
}
