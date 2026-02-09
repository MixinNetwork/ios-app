import UIKit

final class VerifyMobileNumberPINValidationViewController: FullscreenPINValidationViewController {
    
    private let intent: MobileNumberVerificationContext.Intent
    
    init(intent: MobileNumberVerificationContext.Intent) {
        self.intent = intent
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func pinIsVerified(pin: String) {
        let context = MobileNumberVerificationContext(intent: intent, pin: pin)
        let number = VerifyMobileNumberInputNumberViewController(context: context)
        navigationController?.pushViewController(replacingCurrent: number, animated: true)
    }
    
}
