import UIKit

final class RecoveryContactVerifyPINViewController: FullscreenPINValidationViewController {
    
    static func contained() -> ContainerViewController {
        let viewController = RecoveryContactVerifyPINViewController()
        let container = ContainerViewController.instance(viewController: viewController, title: "")
        return container
    }
    
    override func pinIsVerified(pin: String) {
        let vc = RecoveryContactSelectorViewController(pin: pin)
        let title = R.string.localizable.select_emergency_contact()
        let container = ContainerViewController.instance(viewController: vc, title: title)
        container.loadViewIfNeeded()
        container.leftButton.alpha = 0
        navigationController?.pushViewController(container, animated: true)
    }
    
}
