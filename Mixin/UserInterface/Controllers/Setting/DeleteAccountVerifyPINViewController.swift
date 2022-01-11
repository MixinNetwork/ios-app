import UIKit

class DeleteAccountVerifyPINViewController: VerifyPinViewController {
    
    var onSuccess: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func pinIsVerified(pin: String) {
        pinField.resignFirstResponder()
        dismiss(animated: true, completion: onSuccess)
    }
    
}
