import UIKit
import MixinServices

class EmergencyContactLoginVerificationCodeViewController: LoginVerificationCodeViewController {
    
    var emergencyContactIdentityNumber = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = Localized.NAVIGATION_TITLE_ENTER_EMERGENCY_CONTACT_VERIFICATION_CODE(id: emergencyContactIdentityNumber)
        resendButton.isHidden = true
    }
    
    override func login(code: String, registrationId: Int, key: Ed25519PrivateKey) {
        let sessionSecret = key.publicKey.rawRepresentation.base64EncodedString()
        EmergencyAPI.verifySession(id: context.verificationId, code: code, sessionSecret: sessionSecret, registrationId: registrationId) { [weak self] (result) in
            if case .success = result {
                HomeViewController.showChangePhoneNumberTips = true
            }
            DispatchQueue.global().async {
                self?.handleLoginResult(result, key: key)
            }
        }
    }
    
}
