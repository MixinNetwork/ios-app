import UIKit
import MixinServices

class VerifyMobileNumberOneTimeCodeViewController: VerificationCodeViewController {
    
    private var context: MobileNumberVerificationContext
    
    private lazy var captcha = Captcha(viewController: self)
    
    init(context: MobileNumberVerificationContext) {
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
        let popBackAction = UIAlertAction(
            title: R.string.localizable.ok(),
            style: .default
        ) { _ in
            guard let navigationController = self.navigationController else {
                return
            }
            var viewControllers = navigationController.viewControllers
            let index = viewControllers.firstIndex(where: { controller in
                controller is VerifyMobileNumberInputNumberViewController
            })
            if let index {
                viewControllers.removeLast(viewControllers.count - index)
                navigationController.setViewControllers(viewControllers, animated: true)
            } else {
                navigationController.popToRootViewController(animated: true)
            }
        }
        isBusy = true
        AccountAPI.verifyPhoneNumber(
            verificationID: context.verificationID,
            purpose: context.intent.verificationPurpose,
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
                let alert = switch self.context.intent {
                case .periodicVerification:
                    UIAlertController(
                        title: R.string.localizable.verification_successful(),
                        message: R.string.localizable.sms_verified_description(),
                        preferredStyle: .alert
                    )
                case .addMobileNumber:
                    UIAlertController(
                        title: R.string.localizable.mobile_number_added(),
                        message: R.string.localizable.mobile_number_added_description(),
                        preferredStyle: .alert
                    )
                case .changeMobileNumber:
                    UIAlertController(
                        title: R.string.localizable.mobile_number_changed(),
                        message: R.string.localizable.sms_verified_description(),
                        preferredStyle: .alert
                    )
                }
                alert.addAction(popBackAction)
                self.present(alert, animated: true)
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
            purpose: context.intent.verificationPurpose,
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
            case let .failure(.response(error)) where .requiresCaptcha ~= error:
                self.captcha.validate(errorDescription: error.description) { [weak self] (result) in
                    switch result {
                    case .success(let token):
                        self?.requestVerificationCode(captchaToken: token)
                    default:
                        self?.resendButton.isBusy = false
                    }
                }
            case let.failure(error):
                self.alert(error.localizedDescription)
                self.resendButton.isBusy = false
            }
        }
    }
    
}
