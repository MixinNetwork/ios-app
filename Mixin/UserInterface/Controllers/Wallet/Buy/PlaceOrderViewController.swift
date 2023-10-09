import UIKit
import MixinServices

final class PlaceOrderViewController: UIViewController {
    
    private class View: UIView {
        
        override var intrinsicContentSize: CGSize {
            CGSize(width: super.intrinsicContentSize.width, height: 20)
        }
        
    }
    
    var onApprove: (() -> Void)?
    
    override func loadView() {
        view = View()
    }
    
}

extension PlaceOrderViewController: AuthenticationIntentViewController {
    
    var intentTitle: String {
        R.string.localizable.verify_pin()
    }
    
    var intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? {
        nil
    }
    
    var intentSubtitle: String {
        ""
    }
    
    var isBiometryAuthAllowed: Bool {
        true
    }
    
    var inputPINOnAppear: Bool {
        true
    }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (Swift.Error?) -> Void
    ) {
        AccountAPI.verify(pin: pin) { result in
            switch result {
            case .success:
                completion(nil)
                self.presentingViewController?.dismiss(animated: true) {
                    self.onApprove?()
                }
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
        
    }
    
}
