import UIKit

final class RecoveryContactVerifyPINViewController: FullscreenPINValidationViewController {
    
    override func pinIsVerified(pin: String) {
        let vc = RecoveryContactSelectorViewController(pin: pin)
        navigationController?.pushViewController(vc, animated: true)
    }
    
}
