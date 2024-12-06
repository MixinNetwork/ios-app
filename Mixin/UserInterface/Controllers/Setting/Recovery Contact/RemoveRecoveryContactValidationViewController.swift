import UIKit
import MixinServices

class RemoveRecoveryContactValidationViewController: PinValidationViewController {
    
    convenience init() {
        self.init(nib: R.nib.pinValidationView)
        transitioningDelegate = presentationManager
        modalPresentationStyle = .custom
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        descriptionLabel.text = R.string.localizable.setting_emergency_pin_tip()
    }
    
    override func validate(pin: String) {
        EmergencyAPI.delete(pin: pin) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.loadingIndicator.stopAnimating()
            switch result {
            case .success(let account):
                LoginManager.shared.setAccount(account)
                if let navigationController = UIApplication.homeNavigationController {
                    var viewControllers = navigationController.viewControllers
                    if viewControllers.last is ViewRecoveryContactViewController {
                        viewControllers.removeLast()
                    }
                    navigationController.setViewControllers(viewControllers, animated: false)
                }
                weakSelf.dismiss(animated: true, completion: nil)
            case .failure(let error):
                weakSelf.handle(error: error)
            }
        }
    }
    
}
