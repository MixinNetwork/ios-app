import UIKit
import MixinServices

class EmergencyContactLoginVerificationCodeViewController: LoginVerificationCodeViewController {
    
    var emergencyContactIdentityNumber = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = Localized.NAVIGATION_TITLE_ENTER_EMERGENCY_CONTACT_VERIFICATION_CODE(id: emergencyContactIdentityNumber)
        resendButton.isHidden = true
    }
    
    override func login(code: String, registrationId: Int, keyPair: KeyUtil.RSAKeyPair) {
        EmergencyAPI.shared.verifySession(id: context.verificationId, code: code, sessionSecret: keyPair.publicKey, registrationId: registrationId) { [weak self] (result) in
            if case .success = result {
                HomeViewController.showChangePhoneNumberTips = true
            }
            DispatchQueue.global().async {
                self?.handleLoginResult(result, privateKeyPem: keyPair.privateKeyPem)
            }
        }
    }
    
}
