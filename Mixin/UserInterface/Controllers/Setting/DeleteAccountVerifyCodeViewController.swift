import UIKit
import MixinServices

final class DeleteAccountVerifyCodeViewController: VerificationCodeViewController {
    
    private var context: VerifyNumberContext!
    
    deinit {
        CaptchaManager.shared.clean()
    }
     
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.navigation_title_enter_verification_code(context.numberRepresentation)
    }
    
    override func layout(for keyboardFrame: CGRect) {
        if keyboardFrame.height > keyboardLayoutGuideHeightConstraint.constant {
            keyboardLayoutGuideHeightConstraint.constant = keyboardFrame.height
        }
        view.layoutIfNeeded()
    }
    
    override func verificationCodeFieldEditingChanged(_ sender: Any) {
        let code = verificationCodeField.text
        let codeCountMeetsRequirement = code.count == verificationCodeField.numberOfDigits
        continueButton.isHidden = !codeCountMeetsRequirement
        if !isBusy && codeCountMeetsRequirement {
            verifyCode()
        }
    }
    
    override func continueAction(_ sender: Any) {
        verifyCode()
    }
    
    override func requestVerificationCode(captchaToken token: CaptchaToken?) {
        //TODO: ‼️ add new purpose
        AccountAPI.sendCode(to: context.number, captchaToken: token, purpose: .phone) { [weak self] (result) in
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
    
    class func instance(context: VerifyNumberContext) -> UIViewController {
        let vc = DeleteAccountVerifyCodeViewController()
        vc.context = context
        return ContainerViewController.instance(viewController: vc, title: "")
    }

}

extension DeleteAccountVerifyCodeViewController {
    
    private func verifyCode() {
        //TODO: ‼️ new api verify number without pin and process failure 
        isBusy = true
        let code = verificationCodeField.text
        let request = AccountRequest(code: code, registrationId: nil, pin: context.pin, sessionSecret: nil)
        AccountAPI.changePhoneNumber(verificationId: context.verificationId, accountRequest: request, completion: { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case .success:
                UIView.animate(withDuration: 0.3) {
                    weakSelf.verificationCodeField.resignFirstResponder()
                } completion: { _ in
                    DeleteAccountConfirmWindow.instance().presentPopupControllerAnimated()
                }
            case let .failure(error):
                weakSelf.isBusy = false
                weakSelf.verificationCodeField.clear()
                PINVerificationFailureHandler.handle(error: error) { [weak self] (description) in
                    self?.alert(description)
                }
            }
        })
    }
    
}
