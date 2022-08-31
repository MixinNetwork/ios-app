import UIKit
import MixinServices

class ChangeNumberVerificationCodeViewController: VerificationCodeViewController {
    
    var context: ChangeNumberContext!
    
    deinit {
        CaptchaManager.shared.clean()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.landing_validation_title(context.newNumberRepresentation)
    }
    
    override func verificationCodeFieldEditingChanged(_ sender: Any) {
        let code = verificationCodeField.text
        let codeCountMeetsRequirement = code.count == verificationCodeField.numberOfDigits
        continueButton.isHidden = !codeCountMeetsRequirement
        if !isBusy && codeCountMeetsRequirement {
            changePhoneNumber()
        }
    }
    
    override func continueAction(_ sender: Any) {
        changePhoneNumber()
    }
    
    private func changePhoneNumber() {
        let code = verificationCodeField.text
        let context = self.context!
        isBusy = true
        AccountAPI.changePhoneNumber(verificationID: context.verificationId, code: code, pin: context.pin) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case .success(let account):
                LoginManager.shared.setAccount(account)
                weakSelf.verificationCodeField.resignFirstResponder()
                weakSelf.alert(nil, message: R.string.localizable.changed(), handler: { (_) in
                    weakSelf.navigationController?.dismiss(animated: true, completion: nil)
                })
            case let .failure(error):
                weakSelf.isBusy = false
                weakSelf.verificationCodeField.clear()
                PINVerificationFailureHandler.handle(error: error) { [weak self] (description) in
                    self?.alert(description)
                }
            }
        }
    }
    
    override func requestVerificationCode(captchaToken token: CaptchaToken?) {
        AccountAPI.sendCode(to: context.newNumber, captchaToken: token, purpose: .phone) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case .success(let verification):
                weakSelf.context.verificationId = verification.id
                weakSelf.resendButton.isBusy = false
                weakSelf.resendButton.beginCountDown(weakSelf.resendInterval)
            case let.failure(error):
                switch error {
                case .requiresCaptcha:
                    CaptchaManager.shared.validate(on: weakSelf) { (result) in
                        switch result {
                        case .success(let token):
                            self?.requestVerificationCode(captchaToken: token)
                        default:
                            self?.resendButton.isBusy = false
                        }
                    }
                default:
                    weakSelf.alert(error.localizedDescription)
                    weakSelf.resendButton.isBusy = false
                }
            }
        }
    }
    
}
