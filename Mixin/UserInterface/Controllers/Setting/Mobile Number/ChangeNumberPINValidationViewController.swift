import UIKit

final class ChangeNumberPINValidationViewController: FullscreenPINValidationViewController {
    
    override func pinIsVerified(pin: String) {
        let context = ChangeNumberContext(pin: pin)
        let vc = ChangeNumberNewNumberViewController(context: context)
        navigationController?.pushViewController(vc, animated: true)
    }
    
}
