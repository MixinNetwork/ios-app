import UIKit
import MixinServices

final class RecoveryContactLoginVerificationCodeViewController: LoginVerificationCodeViewController {
    
    private let identityNumber: String
    
    init(context: PhoneNumberVerificationContext, identityNumber: String) {
        self.identityNumber = identityNumber
        super.init(context: context)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.setting_emergency_send_code(identityNumber)
        resendButton.isHidden = true
    }
    
    override func login(code: String, registrationId: Int, sessionKey: Ed25519PrivateKey) {
        let sessionSecret = sessionKey.publicKey.rawRepresentation.base64EncodedString()
        EmergencyAPI.verifySession(
            id: context.verificationID,
            code: code,
            sessionSecret: sessionSecret,
            registrationId: registrationId
        ) { [weak self] (result) in
            switch result {
            case let .success(account):
                HomeViewController.showChangePhoneNumberTips = true
                if let self, let error = self.login(account: account, sessionKey: sessionKey) {
                    self.handleVerificationCodeError(error)
                }
            case let .failure(error):
                self?.handleVerificationCodeError(error)
            }
        }
    }
    
}

extension RecoveryContactLoginVerificationCodeViewController: Captcha.Reporting {
    
    var reportingContent: (event: Reporter.Event, type: String) {
        (event: .loginCAPTCHA, type: "recovery_contact")
    }
    
}
