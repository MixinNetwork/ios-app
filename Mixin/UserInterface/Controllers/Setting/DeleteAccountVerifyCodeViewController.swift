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
        AccountAPI.sendCode(to: context.number, captchaToken: token, purpose: .deactivated) { [weak self] (result) in
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
        isBusy = true
        verificationCodeField.resignFirstResponder()
        let code = verificationCodeField.text
        AccountAPI.deactiveVerification(verificationId: context.verificationId, code: code) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case .success:
                DeleteAccountConfirmWindow.instance(context: weakSelf.context).presentPopupControllerAnimated()
            case let .failure(error):
                weakSelf.verificationCodeField.clear()
                PINVerificationFailureHandler.handle(error: error) { [weak self] (description) in
                    self?.alert(description, cancelHandler: { _ in
                        self?.verificationCodeField.becomeFirstResponder()
                    })
                }
            }
            weakSelf.isBusy = false
        }
    }
    
}
