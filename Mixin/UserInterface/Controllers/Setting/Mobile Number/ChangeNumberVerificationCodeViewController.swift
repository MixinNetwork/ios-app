import UIKit
import MixinServices

class ChangeNumberVerificationCodeViewController: VerificationCodeViewController {
    
    private var context: ChangeNumberContext
    
    private lazy var captcha = Captcha(viewController: self)
    
    init(context: ChangeNumberContext) {
        self.context = context
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
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
        let context = self.context
        isBusy = true
        AccountAPI.changePhoneNumber(
            verificationID: context.verificationID,
            code: code,
            pin: context.pin,
            salt: context.base64Salt
        ) { [weak self] (result) in
            guard let self else {
                return
            }
            switch result {
            case .success(let account):
                LoginManager.shared.setAccount(account)
                self.verificationCodeField.resignFirstResponder()
                self.alert(nil, message: R.string.localizable.changed(), handler: { (_) in
                    guard let navigationController = self.navigationController else {
                        return
                    }
                    var viewControllers = navigationController.viewControllers
                    viewControllers.removeLast(4)
                    navigationController.setViewControllers(viewControllers, animated: true)
                })
            case let .failure(error):
                self.isBusy = false
                self.verificationCodeField.clear()
                PINVerificationFailureHandler.handle(error: error) { [weak self] (description) in
                    self?.alert(description)
                }
            }
        }
    }
    
    override func requestVerificationCode(captchaToken token: CaptchaToken?) {
        AccountAPI.phoneVerifications(
            phoneNumber: context.newNumber,
            base64Salt: context.base64Salt,
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
    
}
