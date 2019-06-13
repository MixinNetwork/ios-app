import UIKit

class ChangeNumberVerifyPinViewController: VerifyPinViewController {
    
    override func pinIsVerified(pin: String) {
        var context = ChangeNumberContext()
        context.pin = pin
        let vc = ChangeNumberNewNumberViewController()
        vc.context = context
        navigationController?.pushViewController(vc, animated: true)
    }
    
}
