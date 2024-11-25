import UIKit
import MixinServices

class ShowRecoveryContactValidationViewController: PinValidationViewController {
    
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
        EmergencyAPI.show(pin: pin) { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.loadingIndicator.stopAnimating()
            switch result {
            case .success(let user):
                weakSelf.dismiss(animated: true, completion: {
                    let vc = RecoveryContactViewController.instance(user: user)
                    UIApplication.homeNavigationController?.pushViewController(vc, animated: true)
                })
            case .failure(let error):
                weakSelf.handle(error: error)
            }
        }
    }
    
}
