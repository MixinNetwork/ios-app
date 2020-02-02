import UIKit
import MixinServices

class LoginNavigationController: LoneBackButtonNavigationController {
    
    class func instance() -> LoginNavigationController {
        let vc = LoginMobileNumberViewController()
        let navigationController = LoginNavigationController(rootViewController: vc)
        return navigationController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        SignalProtocol.shared.initSignal()
    }
    
    override func updateBackButtonAlpha(animated: Bool) {
        let alpha: CGFloat
        if viewControllers.last is LoginMobileNumberViewController || viewControllers.last is UsernameViewController {
            alpha = 0
        } else {
            alpha = 1
        }
        guard abs(backButton.alpha - alpha) > 0.1 else {
            return
        }
        if animated {
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationDuration(0.25)
        }
        backButton.alpha = alpha
        if animated {
            UIView.commitAnimations()
        }
    }
    
}
