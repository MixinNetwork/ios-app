import UIKit

class EmergencyContactVerifyPinViewController: VerifyPinViewController {
    
    override func pinIsVerified(pin: String) {
        let vc = EmergencyContactSelectorViewController(pin: pin)
        let title = R.string.localizable.setting_title_select_emergency_contact()
        let container = ContainerViewController.instance(viewController: vc, title: title)
        container.loadViewIfNeeded()
        container.leftButton.alpha = 0
        navigationController?.pushViewController(container, animated: true)
    }
    
}
