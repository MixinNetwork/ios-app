import UIKit
import MixinServices

final class DeleteAccountVerifyCodeViewController: VerificationCodeViewController {
    
    private var context: DeleteAccountContext
    
    private lazy var captcha = Captcha(viewController: self)
    
    init(context: DeleteAccountContext) {
        self.context = context
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.landing_validation_title(context.phoneNumber)
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
        AccountAPI.deactivateVerifications(
            phoneNumber: context.phoneNumber,
            captchaToken: token
        ) { [weak self] (result) in
            guard let self else {
                return
            }
            switch result {
            case .success(let verification):
                self.context.verificationID = verification.id
                self.resendButton.isBusy = false
                self.resendButton.beginCountDown(self.resendInterval)
            case let.failure(error):
                switch error {
                case .requiresCaptcha:
                    self.captcha.validate { [weak self] (result) in
                        switch result {
                        case .success(let token):
                            self?.requestVerificationCode(captchaToken: token)
                        default:
                            self?.resendButton.isBusy = false
                        }
                    }
                default:
                    self.alert(error.localizedDescription)
                    self.resendButton.isBusy = false
                }
            }
        }
    }
    
    class func instance(context: DeleteAccountContext) -> UIViewController {
        let vc = DeleteAccountVerifyCodeViewController(context: context)
        return ContainerViewController.instance(viewController: vc, title: "")
    }
    
}

extension DeleteAccountVerifyCodeViewController {
    
    private func verifyCode() {
        isBusy = true
        verificationCodeField.resignFirstResponder()
        let code = verificationCodeField.text
        AccountAPI.deactiveVerification(verificationID: context.verificationID, code: code) { [weak self] (result) in
            guard let self else {
                return
            }
            switch result {
            case .success:
                DeleteAccountConfirmWindow
                    .instance(verificationID: self.context.verificationID)
                    .presentPopupControllerAnimated()
            case let .failure(error):
                self.verificationCodeField.clear()
                PINVerificationFailureHandler.handle(error: error) { [weak self] (description) in
                    self?.alert(description, cancelHandler: { _ in
                        self?.verificationCodeField.becomeFirstResponder()
                    })
                }
            }
            self.isBusy = false
        }
    }
    
}
