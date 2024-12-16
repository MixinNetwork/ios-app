import UIKit
import SafariServices
import MixinServices

class LoginVerificationCodeViewController: VerificationCodeViewController, LoginAccountHandler {
    
    var context: PhoneNumberVerificationContext
    
    private lazy var captcha = Captcha(viewController: self)
    
    init(context: PhoneNumberVerificationContext) {
        self.context = context
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = .customerService(target: self, action: #selector(presentCustomerService(_:)))
        titleLabel.text = R.string.localizable.landing_validation_title(context.displayPhoneNumber)
    }
    
    override func verificationCodeFieldEditingChanged(_ sender: Any) {
        let code = verificationCodeField.text
        let codeCountMeetsRequirement = code.count == verificationCodeField.numberOfDigits
        continueButton.isHidden = !codeCountMeetsRequirement
        if !isBusy && codeCountMeetsRequirement {
            login()
        }
    }
    
    override func continueAction(_ sender: Any) {
        login()
    }
    
    override func requestVerificationCode(captchaToken token: CaptchaToken?) {
        AccountAPI.sessionVerifications(
            phoneNumber: context.phoneNumber,
            captchaToken: token
        ) { [weak self] (result) in
            guard let self else {
                return
            }
            switch result {
            case let .success(verification):
                self.context.verificationID = verification.id
                self.context.hasEmergencyContact = verification.hasEmergencyContact
                self.resendButton.isBusy = false
                self.resendButton.beginCountDown(self.resendInterval)
            case .failure(.requiresCaptcha):
                captcha.validate { [weak self] (result) in
                    switch result {
                    case .success(let token):
                        self?.requestVerificationCode(captchaToken: token)
                    default:
                        self?.resendButton.isBusy = false
                    }
                }
            case let .failure(error):
                reporter.report(error: error)
                self.alert(error.localizedDescription)
                self.resendButton.isBusy = false
            }
        }
    }
    
    func login() {
        isBusy = true
        SignalProtocol.shared.initSignal()
        let code = verificationCodeField.text
        let registrationID = Int(SignalProtocol.shared.getRegistrationId())
        let sessionKey = Ed25519PrivateKey()
        login(code: code, registrationId: registrationID, sessionKey: sessionKey)
    }
    
    func login(code: String, registrationId: Int, sessionKey: Ed25519PrivateKey) {
        let sessionSecret = sessionKey.publicKey.rawRepresentation.base64EncodedString()
        AccountAPI.login(
            verificationId: context.verificationID,
            code: code,
            registrationID: registrationId,
            sessionSecret: sessionSecret
        ) { [weak self] (result) in
            guard let self else {
                return
            }
            switch result {
            case let .success(account):
                if let error = self.login(account: account, sessionKey: sessionKey) {
                    self.handleVerificationCodeError(error)
                }
            case let .failure(error):
                self.handleVerificationCodeError(error)
            }
        }
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
    }
    
}
